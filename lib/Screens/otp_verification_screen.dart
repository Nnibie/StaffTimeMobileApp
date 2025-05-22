import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({Key? key}) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  late String _verificationId;
  late String _phoneNumber;
  int? _resendToken;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Resend code timer
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;
  
  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract arguments passed from previous screen
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _verificationId = args['verificationId'];
    _phoneNumber = args['phoneNumber'];
    _resendToken = args['resendToken'];
  }
  
  @override
  void dispose() {
    // Clean up controllers and focus nodes
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }
  
  // TIMER LOGIC
  void _startResendTimer() {
    _timer?.cancel();
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }
  
  // OTP HANDLING
  String _getOtpCode() => _otpControllers.map((controller) => controller.text).join();
  
  bool _isOtpComplete() => _otpControllers.every((controller) => controller.text.isNotEmpty);
  
  void _autoVerifyOtp() {
    if (_isOtpComplete()) {
      _verifyOtp();
    }
  }
  
  // AUTHENTICATION LOGIC
  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    
    final otpCode = _getOtpCode();
    if (otpCode.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Create credential with verification ID and OTP code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpCode,
      );
      
      // Sign in with credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      // Check if we have a user
      if (userCredential.user != null) {
        if (mounted) {
          // Check admin status
          await _checkAdminStatus(userCredential.user!.uid);
        }
      } else {
        _showError('Authentication failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.code == 'invalid-verification-code' 
          ? 'Invalid verification code. Please check and try again.'
          : 'Authentication failed: ${e.message}');
    } catch (e) {
      _showError('An error occurred. Please try again.');
    }
  }
  
  void _showError(String message) {
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }
  
  // ADMIN VERIFICATION AND DATA STORAGE
  Future<void> _checkAdminStatus(String uid) async {
    try {
      // Clean phone number to match Firestore document ID format
      final formattedPhone = _phoneNumber.replaceAll(RegExp(r'\s+'), '');
      
      // Check if phone number exists in Admins collection
      final adminDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(formattedPhone)
          .get();
      
      if (adminDoc.exists) {
        // Store admin data locally
        await _storeAdminData(formattedPhone, adminDoc.data()!);
        
        // Navigate to dashboard
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/dashboard', 
            (route) => false,
          );
        }
      } else {
        // Not an admin - sign out and show error
        await FirebaseAuth.instance.signOut();
        _showError('This phone number is not registered as an admin.');
      }
    } catch (e) {
      _showError('Failed to verify admin status. Please try again.');
      await FirebaseAuth.instance.signOut();
    }
  }
  
  Future<void> _storeAdminData(String phoneNumber, Map<String, dynamic> adminData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store basic admin info
      await prefs.setString('admin_phone', phoneNumber);
      await prefs.setString('admin_fname', adminData['Fname'] ?? '');
      await prefs.setString('admin_lname', adminData['Lname'] ?? '');
      await prefs.setString('admin_oname', adminData['Oname'] ?? '');
      
      // Store client IDs as a JSON string
      if (adminData['Client_IDs'] != null && adminData['Client_IDs'] is List) {
        final List<String> clientIds = List<String>.from(adminData['Client_IDs']);
        await prefs.setStringList('admin_client_ids', clientIds);
      }
      
      // Store login timestamp
      await prefs.setString('last_login', DateTime.now().toIso8601String());
      await prefs.setBool('is_logged_in', true);
    } catch (e) {
      // Silent error - authentication already succeeded
      print('Failed to store admin data: $e');
    }
  }
  
  // RESEND CODE LOGIC
  Future<void> _resendCode() async {
    if (!_canResend) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final cleanPhone = _phoneNumber.replaceAll(RegExp(r'\s'), '');
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: cleanPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            _checkAdminStatus(FirebaseAuth.instance.currentUser!.uid);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _showError(e.code == 'invalid-phone-number' 
              ? 'Please enter a valid phone number'
              : 'Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _startResendTimer();
          
          _showSuccessSnackbar();
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      _showError('An error occurred. Please try again.');
    }
  }
  
  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Verification code sent to $_phoneNumber',
                style: AppTheme.bodySmallStyle.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(15),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundDecorations(),
            _buildBackButton(),
            _buildMainContent(),
          ],
        ),
      ),
    );
  }
  
  // UI COMPONENTS
  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBackButton() {
    return Positioned(
      top: 8,
      left: 8,
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: AppTheme.darkGrey,
          size: 22,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
  
  Widget _buildMainContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAppLogo(),
              const SizedBox(height: 40),
              _buildVerificationHeader(),
              const SizedBox(height: 36),
              _buildOtpInputFields(),
              
              if (_errorMessage != null)
                _buildErrorMessage(),
              
              const SizedBox(height: 40),
              _buildVerifyButton(),
              const SizedBox(height: 24),
              _buildResendSection(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Hero(
            tag: 'app_logo',
            child: Image.asset(
              'Assets/Staff_Time_Icon_green.png',
              height: 80,
              width: 80,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Staff Time',
          style: AppTheme.appTitleStyle.copyWith(
            fontSize: 26,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVerificationHeader() {
    return Column(
      children: [
        Text(
          'OTP Verification',
          style: AppTheme.headerMediumStyle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ve sent a verification code to',
          style: AppTheme.bodyMediumStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          _phoneNumber,
          style: AppTheme.bodyMediumStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildOtpInputFields() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          6,
          (index) => SizedBox(
            width: 42,
            height: 52,
            child: TextFormField(
              controller: _otpControllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: AppTheme.headerLargeStyle,
              maxLength: 1,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.errorColor),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                if (value.isNotEmpty) {
                  // Move to next field
                  if (index < 5) {
                    _focusNodes[index + 1].requestFocus();
                  } else {
                    // Last field, dismiss keyboard
                    _focusNodes[index].unfocus();
                    // Automatically verify if all fields are filled
                    _autoVerifyOtp();
                  }
                } else if (value.isEmpty && index > 0) {
                  // Move to previous field on backspace
                  _focusNodes[index - 1].requestFocus();
                }
              },
              onTap: () {
                // Select all text when tapped
                _otpControllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _otpControllers[index].text.length,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.errorColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isLoading
        ? Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              ),
            ),
          )
        : ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppTheme.primaryColor,
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 16,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Verify & Continue',
                  style: AppTheme.bodyLargeStyle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward,
                  size: 20,
                ),
              ],
            ),
          ),
    );
  }
  
  Widget _buildResendSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _canResend ? Icons.refresh_rounded : Icons.timer_outlined,
            color: _canResend ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: _canResend
              ? GestureDetector(
                  onTap: _resendCode,
                  child: Text(
                    'Didn\'t receive the code? Tap to resend',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                    children: [
                      TextSpan(text: 'Didn\'t receive the code? You can resend in '),
                      TextSpan(
                        text: '$_resendTimer seconds',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}