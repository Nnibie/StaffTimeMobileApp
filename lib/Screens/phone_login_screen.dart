import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:staff_time/services/auth_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({Key? key}) : super(key: key);

  @override
  _PhoneLoginScreenState createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  final _functions = FirebaseFunctions.instance;
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCheckingAdmin = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = '+233 '; // Initialize with Ghana country code
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Format phone number for display
  String _formatPhoneNumber(String text) {
    // Remove all non-digit characters
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return '+233 ';
    }
    
    // Format based on Ghana phone number rules
    String formatted = '+233 ';
    String remainder;
    
    if (digitsOnly.startsWith('233')) {
      // Already has country code
      remainder = digitsOnly.substring(3);
      if (remainder.startsWith('0')) {
        remainder = remainder.substring(1);
      }
    } else if (digitsOnly.startsWith('0')) {
      // Remove leading 0
      remainder = digitsOnly.substring(1);
    } else {
      // Use as is
      remainder = digitsOnly;
    }
    
    // Format with spaces for readability
    for (int i = 0; i < remainder.length; i++) {
      formatted += remainder[i];
      if ((i + 1) % 3 == 0 && i != remainder.length - 1) {
        formatted += ' ';
      }
    }
    
    return formatted;
  }

  // Get cleaned phone number for Firebase in E.164 format
  String _getCleanPhoneNumber() {
    // First remove all spaces from the phone number
    String phoneNumber = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
    
    // Handle different phone number formats and ensure proper E.164 format
    if (!phoneNumber.startsWith('+')) {
      // If no + prefix, add it
      phoneNumber = '+' + phoneNumber;
    }
    
    // Ensure it has Ghana country code
    if (!phoneNumber.startsWith('+233')) {
      if (phoneNumber.startsWith('+')) {
        // Remove the + if it exists
        String digits = phoneNumber.substring(1);
        
        if (digits.startsWith('233')) {
          // Already has country code without +
          phoneNumber = '+' + digits;
        } else if (digits.startsWith('0')) {
          // Has leading 0, replace with +233
          phoneNumber = '+233' + digits.substring(1);
        } else {
          // Assume it's a number without country code or leading 0
          phoneNumber = '+233' + digits;
        }
      }
    }
    
    // Debug logging - print the cleaned phone number
    print('Cleaned phone number: $phoneNumber');
    
    return phoneNumber;
  }

  // Modified _checkIfAdmin method for PhoneLoginScreen class
  Future<bool> _checkIfAdmin(String phoneNumber) async {
    try {
      print('Checking admin status for phone: $phoneNumber');
      
      // Create a simple data object with just the phone number as a string
      final data = {'phoneNumber': phoneNumber};
      
      // Log what we're sending (safely)
      print('Sending data to cloud function: $data');
      
      // Use a fresh instance of FirebaseFunctions
      final functions = FirebaseFunctions.instance;
      
      // Call the cloud function
      final callable = functions.httpsCallable('checkAdminExists');
      final result = await callable.call(data);
      
      // Check if result.data contains 'exists' property
      if (result.data is Map) {
        final exists = result.data['exists'] == true;
        print('Admin check result: $exists');
        return exists;
      }
      
      print('Unexpected result format: ${result.data}');
      return false;
    } catch (e) {
      // Log the error
      print('Error checking admin status: $e');
      
      // Return false instead of throwing - handle the error in the UI
      return false;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isCheckingAdmin = true;
    });

    try {
      final phoneNumber = _getCleanPhoneNumber();
      
      // Debug: Print the phone number we're checking
      print('Checking admin status for: $phoneNumber');
      
      // First check if the user is an admin using Cloud Function
      bool isAdmin = await _checkIfAdmin(phoneNumber);
      
      // Update state to indicate we've finished checking admin status
      if (mounted) {
        setState(() {
          _isCheckingAdmin = false;
        });
      }
      
      if (!isAdmin) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'This phone number is not registered as an admin.';
          });
        }
        return;
      }
      
      // If admin, proceed with phone verification with timeout settings
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            // Navigate immediately without showing dialog
            Navigator.pushNamed(
              context,
              '/verify-otp',
              arguments: {
                'verificationId': verificationId,
                'phoneNumber': phoneNumber,
                'resendToken': resendToken,
              },
            );
          }
        },
        onVerificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          
          if (mounted) {
            setState(() {
              _isLoading = false;
              // More user-friendly error message for reCAPTCHA/app verification issues
              if (e.code == 'missing-client-identifier') {
                _errorMessage = 'App verification failed. Please check your internet connection and try again.';
              } else {
                _errorMessage = e.code == 'invalid-phone-number' 
                    ? 'Please enter a valid phone number'
                    : 'Verification failed: ${e.message}';
              }
            });
          }
        },
        onAutoVerificationCompleted: (PhoneAuthCredential credential) async {
          print('Auto verification completed');
          try {
            await _authService.signInWithCredential(credential);
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          } catch (e) {
            print('Error during auto sign in: $e');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Authentication failed: $e';
              });
            }
          }
        },
        onError: (e) {
          print('General verification error: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'An error occurred. Please try again.';
            });
          }
        },
        // Add timeout settings
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print('Exception in _handleLogin: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred. Please try again.';
        });
      }
    }
  }

  // UI building code remains the same...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background decoration
            _buildBackgroundDecoration(),
            
            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildLogoSection(),
                      const SizedBox(height: 50),
                      
                      // Login Header
                      _buildHeaderSection(),
                      const SizedBox(height: 35),
                      
                      // Phone Number Input
                      _buildPhoneInputField(),
                      
                      // Error Message
                      if (_errorMessage != null)
                        _buildErrorMessage(),
                      
                      const SizedBox(height: 40),
                      
                      // Continue Button
                      _buildContinueButton(),
                      
                      const SizedBox(height: 24),
                      
                      // Terms and Conditions
                      _buildTermsAndConditions(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UI building methods unchanged
  Widget _buildBackgroundDecoration() {
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

  Widget _buildLogoSection() {
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

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Text(
          'Admin Login',
          style: AppTheme.headerMediumStyle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter your Ghana phone number to continue',
          style: AppTheme.bodyMediumStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPhoneInputField() {
    return Container(
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
      child: TextFormField(
        controller: _phoneController,
        decoration: InputDecoration(
          labelText: 'Ghana Phone Number',
          labelStyle: TextStyle(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
          hintText: '+233 XX XXX XXXX',
          hintStyle: TextStyle(
            color: AppTheme.tertiaryTextColor,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.phone_android_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.errorColor,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        style: AppTheme.bodyLargeStyle.copyWith(
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppTheme.primaryColor,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
        ],
        onChanged: (value) {
          final formatted = _formatPhoneNumber(value);
          if (formatted != value) {
            _phoneController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty || value == '+233 ') {
            return 'Please enter your phone number';
          }
          
          final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
          
          if (digitsOnly.length < 12 ||
              (!value.startsWith('+233') && !value.contains('233'))) {
            return 'Please enter a valid Ghana phone number';
          }
          return null;
        },
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

  Widget _buildContinueButton() {
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isCheckingAdmin ? 'Verifying admin...' : 'Sending SMS code...',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ElevatedButton(
              onPressed: _handleLogin,
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
                    'Continue',
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

  Widget _buildTermsAndConditions() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            color: AppTheme.secondaryTextColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'By continuing, you agree to our Terms of Service and Privacy Policy',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}