// lib/services/admin_auth_service.dart (Updated)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // The signInWithUsername method is no longer needed for the OTP flow.
  // You can keep it if you plan to have both login methods,
  // but for now, we will focus on the OTP flow.

  /// Signs out the current admin user. This is still needed.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

/// The AdminUser data model. This class does not need any changes.
class AdminUser {
  final String uid;
  final String firstName;
  final String lastName;
  final String username;
  final String phone;
  final List<String> clientIds;

  AdminUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.phone,
    required this.clientIds,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AdminUser(
      uid: doc.id,
      firstName: data['Fname'] ?? '',
      lastName: data['Lname'] ?? '',
      username: data['username'] ?? '',
      phone: data['phone'] ?? '',
      clientIds: List<String>.from(data['Client_IDs'] ?? []),
    );
  }
}