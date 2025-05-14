import 'package:flutter/material.dart';
import 'package:staff_time/app_theme.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(  // Changed from Scaffold to Container since the parent already has AppBar
      color: AppTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'This is a placeholder for the staff screen',
              style: AppTheme.bodyMediumStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}