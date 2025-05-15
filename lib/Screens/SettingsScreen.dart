import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_time/app_theme.dart';
import 'package:staff_time/Widgets/utility/time_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

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
  TimeOfDay _autoClockOutTime = const TimeOfDay(hour: 17, minute: 30); // New auto-clock-out time
  bool _isLoading = true;
  bool _isSaving = false;

  // Firestore reference - matches existing database structure
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _clientsCollection = 'Clients';
  final String _pwaDocumentId = 'PWA';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize time settings if needed
      await _timeSettings.init();
      
      // Get local settings
      final lateTime = _timeSettings.lateTime;
      final earlyDepartureTime = _timeSettings.earlyDepartureTime;
      
      // Get Firestore settings
      final pwaDocRef = _firestore
          .collection(_clientsCollection)
          .doc(_pwaDocumentId);
      
      final docSnapshot = await pwaDocRef.get();
      
      // Set auto-clock-out time from Firestore if available
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('settings') && data['settings'] is Map) {
          final settings = data['settings'] as Map;
          if (settings.containsKey('auto_clock_out_hour') && settings.containsKey('auto_clock_out_minute')) {
            final hour = settings['auto_clock_out_hour'] as int;
            final minute = settings['auto_clock_out_minute'] as int;
            _autoClockOutTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
      
      setState(() {
        _lateTime = lateTime;
        _earlyDepartureTime = earlyDepartureTime;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Save to SharedPreferences for local settings
      final prefs = await SharedPreferences.getInstance();
      
      // Save late time
      await prefs.setInt('late_hour', _lateTime.hour);
      await prefs.setInt('late_minute', _lateTime.minute);
      
      // Save early departure time
      await prefs.setInt('early_departure_hour', _earlyDepartureTime.hour);
      await prefs.setInt('early_departure_minute', _earlyDepartureTime.minute);
      
      // Save to Firestore for global settings - nested in the PWA document
      final pwaDocRef = _firestore.collection(_clientsCollection).doc(_pwaDocumentId);
      
      // Use a transaction to update the settings field
      await _firestore.runTransaction((transaction) async {
        // Get the current document
        final docSnapshot = await transaction.get(pwaDocRef);
        
        if (docSnapshot.exists) {
          // Get the current data
          final data = docSnapshot.data() ?? {};
          
          // Get or create settings map
          final Map<String, dynamic> settings = 
              (data.containsKey('settings') && data['settings'] is Map) 
              ? Map<String, dynamic>.from(data['settings']) 
              : {};
          
          // Update settings map with new values
          settings['late_hour'] = _lateTime.hour;
          settings['late_minute'] = _lateTime.minute;
          settings['early_departure_hour'] = _earlyDepartureTime.hour;
          settings['early_departure_minute'] = _earlyDepartureTime.minute;
          settings['auto_clock_out_hour'] = _autoClockOutTime.hour;
          settings['auto_clock_out_minute'] = _autoClockOutTime.minute;
          settings['updated_at'] = FieldValue.serverTimestamp();
          
          // Update the document
          transaction.update(pwaDocRef, {'settings': settings});
        } else {
          // Document doesn't exist, create it with settings
          transaction.set(pwaDocRef, {
            'name': 'Prudent Way Academy',
            'settings': {
              'late_hour': _lateTime.hour,
              'late_minute': _lateTime.minute,
              'early_departure_hour': _earlyDepartureTime.hour,
              'early_departure_minute': _earlyDepartureTime.minute,
              'auto_clock_out_hour': _autoClockOutTime.hour,
              'auto_clock_out_minute': _autoClockOutTime.minute,
              'updated_at': FieldValue.serverTimestamp(),
            }
          });
        }
        
        return null;
      });
      
      // Re-initialize time settings to ensure singleton is updated
      await _timeSettings.init();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
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

  Future<void> _selectAutoClockOutTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _autoClockOutTime,
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
    
    if (pickedTime != null && pickedTime != _autoClockOutTime) {
      setState(() {
        _autoClockOutTime = pickedTime;
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with save button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time Settings',
                        style: AppTheme.headerLargeStyle,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('About Time Settings', style: AppTheme.headerMediumStyle),
                                content: Text(
                                  'These settings define the thresholds for staff attendance tracking.\n\n'
                                  'Changes will be applied for all new attendance records.',
                                  style: AppTheme.bodyMediumStyle,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('CLOSE'),
                                  ),
                                ],
                              ),
                            );
                          },
                          tooltip: 'Time Settings Information',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure attendance tracking thresholds',
                    style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor),
                  ),
                  const SizedBox(height: 24),
                  
                  // Time Settings Card
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
                        
                        const Divider(height: 32),
                        
                        // Auto clock-out setting (new)
                        _buildSettingItem(
                          icon: Icons.timer_off,
                          title: 'Auto Clock-Out Time',
                          subtitle: 'System will automatically clock out staff at this time if not done manually',
                          value: _formatTimeOfDay(_autoClockOutTime),
                          onTap: _selectAutoClockOutTime,
                          highlight: true, // Highlight this new setting
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // System Information Header
                  Text(
                    'System Information',
                    style: AppTheme.headerLargeStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Application details and version information',
                    style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  
                  // App Info Card
                  Container(
                    decoration: AppTheme.cardDecoration,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.timer,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            'Staff Time',
                            style: AppTheme.headerSmallStyle,
                          ),
                          subtitle: Text(
                            'Staff attendance tracking for Prudent Way Academy',
                            style: AppTheme.bodySmallStyle,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              'v1.0.2',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoButton(
                              icon: Icons.help_outline,
                              label: 'Help',
                              onTap: () {
                                // Add help functionality
                              },
                            ),
                            _buildInfoButton(
                              icon: Icons.policy_outlined,
                              label: 'Privacy',
                              onTap: () {
                                // Add privacy policy functionality
                              },
                            ),
                            _buildInfoButton(
                              icon: Icons.update,
                              label: 'Check Updates',
                              onTap: () {
                                // Add update check functionality
                              },
                            ),
                          ],
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: AppTheme.primaryButtonStyle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
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
    bool highlight = false,
  }) {
    return Material(
      color: highlight ? AppTheme.primaryColor.withOpacity(0.05) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: highlight 
                      ? AppTheme.primaryColor.withOpacity(0.15) 
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: highlight
                      ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1)
                      : null,
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
      ),
    );
  }

  Widget _buildInfoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}