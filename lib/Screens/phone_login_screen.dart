import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:staff_time/theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'otp_verification_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  final String senderId;
  const PhoneLoginScreen({Key? key, required this.senderId}) : super(key: key);

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _appSignature;

  @override
  void initState() {
    super.initState();
    _getAppSignature();
  }

  Future<void> _getAppSignature() async {
    try {
      // This helps with automatic SMS code retrieval on Android
      _appSignature = await SmsAutoFill().getAppSignature;
    } catch (e) {
      // Fail silently if it can't get the signature. The app will still work.
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Normalizes various phone number formats to a 9-digit local format for the backend.
  String _normalizePhone(String raw) {
    String digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length == 12 && digitsOnly.startsWith('233')) {
      return digitsOnly.substring(3); // from +233...
    } else if (digitsOnly.length == 10 && digitsOnly.startsWith('0')) {
      return digitsOnly.substring(1); // from 0...
    } else if (digitsOnly.length == 9) {
      return digitsOnly; // already 9 digits
    }
    return digitsOnly; // fallback
  }

  /// Validates the form, calls the cloud function to send an OTP, and handles navigation.
  Future<void> _sendOTP() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phoneForBackend = _normalizePhone(_phoneController.text.trim());

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendClientOtp');
      await callable.call(<String, dynamic>{
        'phone': phoneForBackend,
        'sender': widget.senderId,
        'appSignature': _appSignature ?? '',
      });

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phone: phoneForBackend,
            senderId: widget.senderId,
            appSignature: _appSignature,
          ),
        ));
      }
    } on FirebaseFunctionsException catch (e) {
      // Provide user-friendly messages for common errors.
      String friendlyMessage;
      switch (e.code) {
        case 'permission-denied':
          friendlyMessage = 'This phone number is not a registered admin.';
          break;
        case 'resource-exhausted':
          friendlyMessage = 'OTP recently requested. Please wait.';
          break;
        case 'invalid-argument':
          friendlyMessage = 'The phone number format is invalid.';
          break;
        default:
          friendlyMessage = e.message ?? 'A server error occurred. Please try again.';
      }
      setState(() => _errorMessage = friendlyMessage);
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected network error occurred.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  _buildHeaderSection(),
                  const SizedBox(height: 35),
                  _buildPhoneInputField(),
                  if (_errorMessage != null) _buildErrorMessage(),
                  const SizedBox(height: 40),
                  _buildActionButton(),
                  const SizedBox(height: 24),
                  _buildSecurityFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Builder Widgets ---

  Widget _buildLogoSection() {
    return FadeInDown(
      duration: const Duration(milliseconds: 800),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(38),
                  spreadRadius: 5,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Hero(
              tag: 'app_logo',
              child: Image.asset('Assets/Staff_Time_Icon_green.png', height: 80, width: 80),
            ),
          ),
          const SizedBox(height: 22),
          Text('Staff Time', style: AppTheme.appTitleStyle),
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
      ),
    );
  }

  Widget _buildHeaderSection() {
    return FadeInDown(
      delay: const Duration(milliseconds: 200),
      child: Column(
        children: [
          Text('Login', style: AppTheme.headerMediumStyle),
          const SizedBox(height: 12),
          Text(
            'Enter your phone number to continue',
            style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInputField() {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(20),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone_outlined, color: AppTheme.primaryColor, size: 22),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          validator: (value) => (value?.isEmpty ?? true) ? 'Please enter your phone number' : null,
          onFieldSubmitted: (_) => _sendOTP(),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return FadeIn(
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
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
      ),
    );
  }

  Widget _buildActionButton() {
    return FadeInUp(
      delay: const Duration(milliseconds: 600),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _sendOTP,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppTheme.primaryColor,
            shadowColor: AppTheme.primaryColor.withAlpha(102),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Send OTP',
                      style: AppTheme.bodyLargeStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return FadeInUp(
      delay: const Duration(milliseconds: 700),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
        ),
        child:  Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.secondaryTextColor, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Your login is secure and private.',
                style: AppTheme.bodySmallStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}