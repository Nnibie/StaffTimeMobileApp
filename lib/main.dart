// lib/main.dart (Corrected)

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:developer';
import 'Screens/phone_login_screen.dart';

import 'package:staff_time/theme/app_theme.dart';
import 'package:staff_time/screens/dashboard.dart'; 
import 'package:staff_time/services/admin_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Time',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<AdminUser?> _fetchAdminData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Admins').doc(uid).get();
      if (doc.exists) {
        return AdminUser.fromFirestore(doc);
      }
      await FirebaseAuth.instance.signOut();
      return null;
    } catch (e) {
      log("Error fetching admin data in AuthWrapper: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          final firebaseUser = snapshot.data!;
          return FutureBuilder<AdminUser?>(
            future: _fetchAdminData(firebaseUser.uid),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (adminSnapshot.hasData && adminSnapshot.data != null) {
                return DashboardScreen(loggedInAdmin: adminSnapshot.data!);
              }
              // --- FIX IS HERE ---
              // Corrected the senderId to be consistent.
              // This value MUST match the 'sender' field in your Firestore 'SenderIDs' collection.
              return const PhoneLoginScreen(senderId: "Staff Time");
            },
          );
        }

        // If no user is logged in, show the Phone Login Screen.
        // --- FIX IS HERE ---
        // Corrected the senderId to be consistent.
        return const PhoneLoginScreen(senderId: "Staff Time");
      },
    );
  }
}