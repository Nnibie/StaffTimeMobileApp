import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class to manage attendance time settings globally
class TimeSettings {
  static final TimeSettings _instance = TimeSettings._internal();
  
  factory TimeSettings() {
    return _instance;
  }
  
  TimeSettings._internal();

  // Default values
  TimeOfDay _lateTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _earlyDepartureTime = const TimeOfDay(hour: 16, minute: 30);
  
  // Getter methods
  TimeOfDay get lateTime => _lateTime;
  TimeOfDay get earlyDepartureTime => _earlyDepartureTime;
  
  // Helper getter for expected arrival minutes (used in StaffInfoUtils)
  int get expectedArrivalMinutes => _lateTime.hour * 60 + _lateTime.minute;

  /// Initialize settings from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load late time (default 9:00 AM)
    final lateHour = prefs.getInt('late_hour') ?? 9;
    final lateMinute = prefs.getInt('late_minute') ?? 0;
    
    // Load early departure time (default 4:30 PM)
    final earlyDepartureHour = prefs.getInt('early_departure_hour') ?? 16;
    final earlyDepartureMinute = prefs.getInt('early_departure_minute') ?? 30;
    
    _lateTime = TimeOfDay(hour: lateHour, minute: lateMinute);
    _earlyDepartureTime = TimeOfDay(hour: earlyDepartureHour, minute: earlyDepartureMinute);
  }
  
  /// Check if a given time string (HH:MM) is considered late
  bool isTimeLate(String timeString) {
    try {
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Compare with the late time threshold
      if (hour > _lateTime.hour) return true;
      if (hour == _lateTime.hour && minute > _lateTime.minute) return true;
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if a given time string (HH:MM) is considered early departure
  bool isEarlyDeparture(String timeString) {
    try {
      // If departure time is empty, they're still at work
      if (timeString == '') return false;
      
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Compare with the early departure threshold
      if (hour < _earlyDepartureTime.hour) return true;
      if (hour == _earlyDepartureTime.hour && minute < _earlyDepartureTime.minute) return true;
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Convert TimeOfDay to string format (HH:MM)
  String timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  /// Convert TimeOfDay to minutes past midnight
  int timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }
}