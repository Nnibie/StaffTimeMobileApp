import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_time/app_theme.dart';
import 'package:staff_time/Widgets/utility/time_settings.dart'; // Import TimeSettings utility

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Use the singleton TimeSettings instance
  final TimeSettings _timeSettings = TimeSettings();
  
  // UI state variables
  TimeOfDay _lateTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _earlyDepartureTime = const TimeOfDay(hour: 16, minute: 30);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Initialize time settings if needed
    await _timeSettings.init();
    
    setState(() {
      // Get values from the TimeSettings singleton
      _lateTime = _timeSettings.lateTime;
      _earlyDepartureTime = _timeSettings.earlyDepartureTime;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save late time
    await prefs.setInt('late_hour', _lateTime.hour);
    await prefs.setInt('late_minute', _lateTime.minute);
    
    // Save early departure time
    await prefs.setInt('early_departure_hour', _earlyDepartureTime.hour);
    await prefs.setInt('early_departure_minute', _earlyDepartureTime.minute);
    
    // Re-initialize time settings to ensure singleton is updated
    await _timeSettings.init();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _selectLateTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _lateTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && pickedTime != _lateTime) {
      setState(() {
        _lateTime = pickedTime;
      });
    }
  }

  Future<void> _selectEarlyDepartureTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _earlyDepartureTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && pickedTime != _earlyDepartureTime) {
      setState(() {
        _earlyDepartureTime = pickedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: AppTheme.headerMediumStyle),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Rules',
                    style: AppTheme.headerMediumStyle,
                  ),
                  const SizedBox(height: 20),
                  
                  // Settings Card
                  Container(
                    decoration: AppTheme.cardDecoration,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Late time setting
                        _buildSettingItem(
                          icon: Icons.access_time,
                          title: 'Late Arrival Time',
                          subtitle: 'Staff arriving after this time are marked as late',
                          value: _formatTimeOfDay(_lateTime),
                          onTap: _selectLateTime,
                        ),
                        
                        const Divider(height: 32),
                        
                        // Early departure setting
                        _buildSettingItem(
                          icon: Icons.exit_to_app,
                          title: 'Early Departure Time',
                          subtitle: 'Staff leaving before this time are marked as early departure',
                          value: _formatTimeOfDay(_earlyDepartureTime),
                          onTap: _selectEarlyDepartureTime,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // App Info Card
                  Container(
                    decoration: AppTheme.cardDecoration,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Staff Time',
                          style: AppTheme.headerSmallStyle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Staff attendance tracking for Prudent Way Academy',
                          style: AppTheme.bodyMediumStyle,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Version 1.0.2',
                          style: AppTheme.bodySmallStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading 
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: AppTheme.primaryButtonStyle,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'SAVE SETTINGS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.headerSmallStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmallStyle,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}