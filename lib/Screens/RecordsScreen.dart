import 'package:flutter/material.dart';
import 'package:staff_time/app_theme.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(  // Changed from Scaffold to Container since the parent already has AppBar
      color: AppTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'This is a placeholder for the records screen',
              style: AppTheme.bodyMediumStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}