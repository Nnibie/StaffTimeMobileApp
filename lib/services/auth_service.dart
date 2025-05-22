import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Method to verify phone number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onAutoVerificationCompleted,
    required void Function(Object e) onError,
    Duration timeout = const Duration(seconds: 60), // Default timeout
  }) async {
    try {
      // Print debug information
      print('Starting phone verification for: $phoneNumber');
      
      // Configure verification settings
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          print('Auto-verification completed');
          onAutoVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          onVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('SMS code sent to $phoneNumber');
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle auto retrieval timeout
          print('Auto retrieval timeout for $verificationId');
        },
        timeout: timeout,
        // Important: forceResendingToken should be null for initial send
        forceResendingToken: null,
      );
    } catch (e) {
      print('Exception in verifyPhoneNumber: $e');
      onError(e);
    }
  }
  
  // Method to sign in with credential
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    try {
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with credential: $e');
      rethrow;
    }
  }
  
  // Method to sign in with verification ID and SMS code
  Future<UserCredential> signInWithVerificationCode(
    String verificationId,
    String smsCode,
  ) async {
    try {
      // Create a PhoneAuthCredential with the code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Sign in with the credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with verification code: $e');
      rethrow;
    }
  }
  
  // Method to check if user is authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }
  
  // Method to sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}