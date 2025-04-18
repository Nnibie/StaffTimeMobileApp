import 'package:flutter/material.dart';
import 'Screens/Dashboard.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Dashboard()
        
      ),
    );
  }
}
