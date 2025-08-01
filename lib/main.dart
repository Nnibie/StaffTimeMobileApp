import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'Screens/Dashboard.dart'; // Make sure this path is correct
import 'firebase_options.dart'; // Generated by `flutterfire configure`
import 'package:staff_time/Theme/app_theme.dart';

Future<void> main() async {
  // Ensure that Flutter bindings are initialized before calling Firebase
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Keep the splash screen visible during initialization
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  try {
    // --- Step 1: Initialize Firebase ---
    // This must happen before any other Firebase services are used.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // --- Step 2: Sign in Anonymously (The FIX) ---
    // We check if a user is already signed in from a previous session.
    // If not, we create a new anonymous session.
    if (FirebaseAuth.instance.currentUser == null) {
      print("No user found, signing in anonymously...");
      await FirebaseAuth.instance.signInAnonymously();
      print("Anonymous sign-in successful!");
    } else {
      print("Existing user session found.");
    }

  } catch (e) {
    // If anything goes wrong during initialization or sign-in, log the error.
    print("Error during app startup: $e");
  } finally {
    // --- Step 3: Remove the Splash Screen ---
    // This happens after all initialization is complete (or has failed),
    // ensuring the user never sees a broken loading state.
    print("Initialization complete, removing splash screen.");
    FlutterNativeSplash.remove();
  }
  
  // Start your Flutter app
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // The home widget remains your Dashboard. By the time this is built,
      // the user is already authenticated.
      home: const Scaffold(
        body: Dashboard(),
      ),
    );
  }
}