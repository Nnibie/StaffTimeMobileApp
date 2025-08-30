// lib/utility/time_settings.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

/// Utility class to manage attendance time settings globally
class TimeSettings {
  static final TimeSettings _instance = TimeSettings._internal();
  
  factory TimeSettings() {
    return _instance;
  }
  
  TimeSettings._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default values, used as a fallback if Firestore data is unavailable
  TimeOfDay _lateTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _earlyDepartureTime = const TimeOfDay(hour: 16, minute: 30);
  
  // Getter methods
  TimeOfDay get lateTime => _lateTime;
  TimeOfDay get earlyDepartureTime => _earlyDepartureTime;
  
  /// Initialize settings by fetching them from the specific client's document in Firestore.
  /// Needs the client's ID to fetch the correct settings.
  Future<void> init(String clientId) async {
    // If there's no client ID, use the default values and exit.
    if (clientId.isEmpty) {
      log('TimeSettings: No Client ID provided, using default times.');
      _resetToDefaults();
      return;
    }

    try {
      // Fetch the specific client's document
      final docRef = _firestore.collection('Clients').doc(clientId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Safely get the 'settings' map from the document data
        final settings = docSnapshot.data()?['settings'] as Map<String, dynamic>? ?? {};
        
        // Load late time, falling back to defaults if fields are missing
        final lateHour = settings['late_hour'] ?? 9;
        final lateMinute = settings['late_minute'] ?? 0;
        
        // Load early departure time, falling back to defaults if fields are missing
        final earlyDepartureHour = settings['early_departure_hour'] ?? 16;
        final earlyDepartureMinute = settings['early_departure_minute'] ?? 30;
        
        _lateTime = TimeOfDay(hour: lateHour, minute: lateMinute);
        _earlyDepartureTime = TimeOfDay(hour: earlyDepartureHour, minute: earlyDepartureMinute);
        log('TimeSettings: Successfully loaded settings for client $clientId.');
      } else {
        // If the document doesn't exist, use the default values
        log('TimeSettings: Client document $clientId not found, using default times.');
        _resetToDefaults();
      }
    } catch (e) {
      // If any other error occurs, use the default values
      log('TimeSettings: Error fetching settings for client $clientId. Error: $e. Using default times.');
      _resetToDefaults();
    }
  }

  /// Resets the times to their default state.
  void _resetToDefaults() {
    _lateTime = const TimeOfDay(hour: 9, minute: 0);
    _earlyDepartureTime = const TimeOfDay(hour: 16, minute: 30);
  }
  
  /// Check if a given time string (HH:MM) is considered late
  bool isTimeLate(String timeString) {
    try {
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
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
      if (timeString == '') return false;
      
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      if (hour < _earlyDepartureTime.hour) return true;
      if (hour == _earlyDepartureTime.hour && minute < _earlyDepartureTime.minute) return true;
      return false;
    } catch (e) {
      return false;
    }
  }
}