import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:staff_time/Screens/phone_login_screen.dart';
import 'package:staff_time/theme/app_theme.dart';
import 'package:staff_time/services/admin_auth_service.dart';

// --- MAIN WIDGET ---

class SettingsScreen extends StatefulWidget {
  // We now require the loggedInAdmin to be passed in.
  final AdminUser loggedInAdmin;

  const SettingsScreen({
    super.key,
    required this.loggedInAdmin,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  TimeOfDay _lateTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _earlyDepartureTime = const TimeOfDay(hour: 16, minute: 30);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _clientsCollection = 'Clients';
  
  // This will hold the client ID for the logged-in admin.
  String? _activeClientId;

  @override
  void initState() {
    super.initState();
    // Use the client ID from the admin user object passed into the widget.
    // If the admin can manage multiple clients, you might build a UI to choose one.
    // For now, we safely take the first one.
    if (widget.loggedInAdmin.clientIds.isNotEmpty) {
      _activeClientId = widget.loggedInAdmin.clientIds.first;
      _loadSettings();
    } else {
      // Handle the case where the admin has no clients assigned.
      setState(() => _isLoading = false);
    }
  }

  /// Loads the attendance settings from Firestore for the admin's client.
  Future<void> _loadSettings() async {
    // If there's no client ID, we can't load anything.
    if (_activeClientId == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final docRef = _firestore.collection(_clientsCollection).doc(_activeClientId!);
      final docSnapshot = await docRef.get();

      if (mounted && docSnapshot.exists) {
        final settings = docSnapshot.data()?['settings'] as Map<String, dynamic>? ?? {};
        setState(() {
          _lateTime = TimeOfDay(hour: settings['late_hour'] ?? 9, minute: settings['late_minute'] ?? 0);
          _earlyDepartureTime = TimeOfDay(
              hour: settings['early_departure_hour'] ?? 16,
              minute: settings['early_departure_minute'] ?? 30);
        });
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Saves the updated attendance settings to Firestore.
  Future<void> _saveSettings() async {
    // If there's no client ID, we can't save anything.
    if (_activeClientId == null) {
      _showErrorSnackBar('Cannot save settings: No client assigned.');
      return;
    }
    
    final Map<String, dynamic> settingsToSave = {
      'settings': {
        'late_hour': _lateTime.hour,
        'late_minute': _lateTime.minute,
        'early_departure_hour': _earlyDepartureTime.hour,
        'early_departure_minute': _earlyDepartureTime.minute,
        'updated_at': FieldValue.serverTimestamp(),
      }
    };

    try {
      await _firestore.collection(_clientsCollection).doc(_activeClientId!).set(settingsToSave, SetOptions(merge: true));
      if (mounted) _showSuccessSnackBar('Settings updated');
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to save settings: $e');
    }
  }

  // --- The rest of your file remains largely the same ---
  // (No changes needed for _pickTime, _signOut, dialogs, formatting, snackbars, etc.)


  /// Shows a time picker with a beautiful, custom-themed AM/PM selector.
  Future<void> _pickTime(BuildContext context, TimeOfDay initialTime, ValueChanged<TimeOfDay> onTimePicked) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: context.theme.copyWith(
              // THIS IS THE NEW, DETAILED THEME FOR THE TIME PICKER
              timePickerTheme: TimePickerThemeData(
                // Colors for the AM/PM selector
                dayPeriodTextColor: MaterialStateColor.resolveWith((states) => states.contains(MaterialState.selected) ? Colors.white : AppTheme.darkGrey),
                dayPeriodColor: MaterialStateColor.resolveWith((states) => states.contains(MaterialState.selected) ? AppTheme.primaryColor : Colors.grey.shade200),
                dayPeriodBorderSide: const BorderSide(color: Colors.transparent),

                // Colors for the clock dial
                dialHandColor: AppTheme.primaryColor,
                dialBackgroundColor: Colors.grey.shade200,
                hourMinuteTextColor: MaterialStateColor.resolveWith((states) => states.contains(MaterialState.selected) ? Colors.white : Colors.black),
                hourMinuteColor: MaterialStateColor.resolveWith((states) => states.contains(MaterialState.selected) ? AppTheme.primaryColor : Colors.transparent),
                
                // General dialog colors
                backgroundColor: AppTheme.backgroundColor,
                shape: RoundedRectangleBorder(borderRadius: AppTheme.defaultBorderRadius),
                helpTextStyle: TextStyle(color: AppTheme.primaryTextColor), // "Select time" text
                
                // OK/Cancel button styles
                confirmButtonStyle: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppTheme.secondaryTextColor),
              ),
              colorScheme: context.colorScheme.copyWith(
                primary: AppTheme.primaryColor, 
                onPrimary: Colors.white, // Text on primary color (like on the selected time)
                surface: AppTheme.backgroundColor, // Background of the picker
                onSurface: AppTheme.primaryTextColor, // Text on the background
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedTime != null) {
      onTimePicked(pickedTime);
    }
  }
  
  /// The actual sign-out logic.
  Future<void> _signOut() async {
    try {
      await AdminAuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PhoneLoginScreen(senderId: "Staff Time",)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error signing out: $e');
    }
  }

  /// Shows a confirmation dialog before signing out.
  Future<void> _showSignOutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppTheme.defaultBorderRadius),
          title: Text('Confirm Sign Out', style: AppTheme.headerSmallStyle),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: AppTheme.secondaryTextColor)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text('Sign Out', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _signOut();
              },
            ),
          ],
        );
      },
    );
  }
  
  /// Formats TimeOfDay to a guaranteed 12-hour AM/PM string (e.g., "7:30 AM").
  String _formatTimeOfDay(TimeOfDay time) {
    if (!mounted) return "";
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    // Show a message if the admin has no clients assigned to them.
    if (_activeClientId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Settings', style: AppTheme.headerMediumStyle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'You are not assigned to manage any clients. Please contact support.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyLargeStyle,
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: AppTheme.headerMediumStyle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadSettings,
                    color: AppTheme.primaryColor,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildAttendanceRulesCard(),
                      ],
                    ),
                  ),
                ),
                // --- Items pinned to the bottom ---
                _buildSignOutButton(),
                _buildAppInfoCard(),
              ],
            ),
    );
  }

  /// A visually enhanced card for managing attendance rules.
  Widget _buildAttendanceRulesCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Rules',
            style: AppTheme.headerMediumStyle,
          ),
          const SizedBox(height: 4),
          Text(
            'Set the times for marking staff as late or leaving early.',
            style: AppTheme.bodySmallStyle,
          ),
          const Divider(height: 32),
          _buildTimeSettingRow(
            icon: Icons.access_time_filled,
            label: 'Late Arrival',
            subtitle: 'Staff are late if they clock-in after this time.',
            currentTime: _lateTime,
            onTap: () => _pickTime(context, _lateTime, (newTime) {
              setState(() => _lateTime = newTime);
              _saveSettings();
            }),
          ),
          const SizedBox(height: 16),
          _buildTimeSettingRow(
            icon: Icons.hourglass_bottom,
            label: 'Early Departure',
            subtitle: 'Staff leave early if they clock-out before this time.',
            currentTime: _earlyDepartureTime,
            onTap: () => _pickTime(context, _earlyDepartureTime, (newTime) {
              setState(() => _earlyDepartureTime = newTime);
              _saveSettings();
            }),
          ),
        ],
      ),
    );
  }
  
  /// Builds the minimalist red sign-out text button.
  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: TextButton(
          onPressed: _showSignOutConfirmationDialog,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'Sign Out',
            style: AppTheme.bodyLargeStyle.copyWith(
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// A reusable and stylish row for displaying and editing a time setting.
  Widget _buildTimeSettingRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required TimeOfDay currentTime,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.defaultBorderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.bodyLargeStyle.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.bodySmallStyle),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _formatTimeOfDay(currentTime),
              style: AppTheme.headerSmallStyle.copyWith(color: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Displays the application version information at the bottom of the screen.
  Widget _buildAppInfoCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // Padding from the screen edge
      child: Center(
        child: Text(
          'Staff Time v1.4.0', 
          style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.secondaryTextColor),
        ),
      ),
    );
  }
}