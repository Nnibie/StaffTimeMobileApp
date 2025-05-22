import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  TimeOfDay _autoClockOutTime = const TimeOfDay(hour: 17, minute: 30);
  bool _isLoading = true;
  bool _isSaving = false;

  // Firestore reference
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
      // Initialize time settings
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
      
      // Save to Firestore for global settings
      final pwaDocRef = _firestore.collection(_clientsCollection).doc(_pwaDocumentId);
      
      // Use a transaction to update the settings field
      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(pwaDocRef);
        
        if (docSnapshot.exists) {
          final data = docSnapshot.data() ?? {};
          
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
          
          transaction.update(pwaDocRef, {'settings': settings});
        } else {
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
      
      // Re-initialize time settings
      await _timeSettings.init();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
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
          : RefreshIndicator(
              onRefresh: _loadSettings,
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with count
                    Row(
                      children: [
                        Text(
                          'Time Settings',
                          style: AppTheme.headerMediumStyle,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '3',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Late Time card
                    _buildSettingCard(
                      icon: Icons.access_time,
                      title: 'Late Arrival',
                      value: _formatTimeOfDay(_lateTime),
                      description: 'Staff arriving after this time are marked late',
                      onTap: _selectLateTime,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Early Departure card
                    _buildSettingCard(
                      icon: Icons.exit_to_app,
                      title: 'Early Departure',
                      value: _formatTimeOfDay(_earlyDepartureTime),
                      description: 'Staff leaving before this time are marked early',
                      onTap: _selectEarlyDepartureTime,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Auto Clock-Out card
                    _buildSettingCard(
                      icon: Icons.timer_off,
                      title: 'Auto Clock-Out',
                      value: _formatTimeOfDay(_autoClockOutTime),
                      description: 'System will automatically clock out staff at this time',
                      onTap: _selectAutoClockOutTime,
                      isHighlighted: true,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // App Version
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Staff Time v1.0.2',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isHighlighted 
              ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3)) 
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isHighlighted 
                      ? AppTheme.primaryColor.withOpacity(0.2) 
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Setting details
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
                      description,
                      style: AppTheme.bodySmallStyle,
                    ),
                  ],
                ),
              ),
              
              // Value
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isHighlighted 
                      ? AppTheme.primaryColor.withOpacity(0.15) 
                      : AppTheme.primaryColor.withOpacity(0.1),
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
              
              // Edit icon
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
}