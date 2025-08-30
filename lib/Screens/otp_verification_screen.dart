import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pinput/pinput.dart';
import 'package:staff_time/theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Make sure these imports match your project structure EXACTLY
import 'package:staff_time/services/admin_auth_service.dart';
import 'package:staff_time/screens/dashboard.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final String senderId;
  final String? appSignature;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.senderId,
    this.appSignature,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _cooldownTimer;
  int _remainingSeconds = 60;
  StreamSubscription<String>? _smsSubscription;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _listenForSms();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    _smsSubscription?.cancel();
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _remainingSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) t.cancel();
      });
    });
  }

  void _listenForSms() async {
    try {
      await SmsAutoFill().listenForCode();
      _smsSubscription = SmsAutoFill().code.listen((String code) {
        if (code.isNotEmpty && mounted) {
          final match = RegExp(r'\d{4}').firstMatch(code);
          if (match != null) {
            setState(() => _otpController.text = match.group(0)!);
            _verifyOTP();
          }
        }
      });
    } catch (e) {
      // Fail silently if the listener can't start.
    }
  }

  String _formatDisplayPhone(String phone) {
    if (phone.length != 9) return phone;
    return '+233 ${phone.substring(0, 2)} ${phone.substring(2, 5)} ${phone.substring(5, 9)}';
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendClientOtp');
      await callable.call({
        'phone': widget.phone,
        'sender': widget.senderId,
        'appSignature': widget.appSignature ?? '',
      });
      _startCooldown();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new OTP has been sent.')));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to resend OTP.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyClientOtp');
      final result = await callable.call(<String, dynamic>{
        'phone': widget.phone,
        'sender': widget.senderId,
        'otp': _otpController.text.trim(),
      });

      final data = result.data;
      if (data != null && data['success'] == true && (data['token'] ?? '').toString().isNotEmpty) {
        final String token = data['token'].toString();
        final userCred = await FirebaseAuth.instance.signInWithCustomToken(token);
        final firebaseUser = userCred.user;

        final adminUid = data['adminUid']?.toString() ?? (firebaseUser?.uid ?? '');
        final firstName = data['firstName'] ?? '';
        final clientIds = List<String>.from(data['clientIds'] ?? []);

        final loggedInAdmin = AdminUser(
          uid: adminUid,
          firstName: firstName,
          lastName: data['lastName'] ?? '',
          username: data['username'] ?? '',
          phone: data['phone'] ?? '',
          clientIds: clientIds,
        );

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(loggedInAdmin: loggedInAdmin)),
          (route) => false,
        );
      } else {
        setState(() => _errorMessage = data?['message'] ?? 'Verification failed.');
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Server error occurred.');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Authentication failed.');
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 64,
      textStyle: AppTheme.headerMediumStyle.copyWith(fontSize: 24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    // --- THE FIX IS HERE ---
    // We create the themed PinTheme objects correctly before using them.
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppTheme.primaryColor),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppTheme.errorColor),
      ),
    );
    // --- END OF FIX ---

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: AppTheme.darkGrey)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogoSection(),
                  const SizedBox(height: 50),
                  FadeInDown(child: Text('Verify Your Phone', style: AppTheme.headerLargeStyle)),
                  const SizedBox(height: 15),
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Enter the 4-digit code sent to\n${_formatDisplayPhone(widget.phone)}',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: Pinput(
                      length: 4,
                      controller: _otpController,
                      pinAnimationType: PinAnimationType.fade,
                      autofocus: true,
                      onCompleted: (_) => _verifyOTP(),
                      defaultPinTheme: defaultPinTheme,
                      // Apply the correctly constructed themes
                      focusedPinTheme: focusedPinTheme,
                      errorPinTheme: errorPinTheme,
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: FadeIn(child: Text(_errorMessage!, style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.errorColor))),
                    ),
                  const SizedBox(height: 40),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOTP,
                        style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: AppTheme.primaryColor,
                            shadowColor: AppTheme.primaryColor.withAlpha(102),
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify & Continue'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    delay: const Duration(milliseconds: 800),
                    child: _remainingSeconds > 0 ? Text('Resend code in $_remainingSeconds s', style: AppTheme.bodySmallStyle) : TextButton(onPressed: _resendOTP, child: const Text('Didn\'t receive the code? Resend')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
     return FadeInDown(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.grey.withAlpha(38), spreadRadius: 5, blurRadius: 15, offset: const Offset(0, 5))]),
            child: Hero(tag: 'app_logo', child: Image.asset('Assets/Staff_Time_Icon_green.png', height: 80, width: 80)),
          ),
          const SizedBox(height: 22),
          Text('Staff Time', style: AppTheme.appTitleStyle),
          const SizedBox(height: 10),
          Container(width: 40, height: 3, decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }
}