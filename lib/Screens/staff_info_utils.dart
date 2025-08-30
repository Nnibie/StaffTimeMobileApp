import 'package:intl/intl.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:flutter/material.dart';

class StaffStats {
  final int totalAttendanceDays;
  final int daysPresent;
  final int daysEarlyArrival;
  final int daysLate;
  final int daysAbsent;
  final int daysMissedIn; // MODIFIED: Added to track missed clock-ins
  final String averageArrivalTime;
  final String averageDepartureTime;
  final double averageHoursWorked;
  final List<double> weeklyAttendanceData;

  StaffStats({
    required this.totalAttendanceDays,
    required this.daysPresent,
    required this.daysEarlyArrival,
    required this.daysLate,
    required this.daysAbsent,
    required this.daysMissedIn, // MODIFIED: Added to constructor
    required this.averageArrivalTime,
    required this.averageDepartureTime,
    required this.averageHoursWorked,
    required this.weeklyAttendanceData,
  });
}

class StaffInfoUtils {
  /// Calculate attendance statistics based on the processed attendance records.
  static void calculateStats({
    required List<Map<String, dynamic>> attendanceRecords,
    required TimeSettings timeSettings,
    required DateTime startDate,
    required DateTime endDate,
    required Function(StaffStats) onStatsCalculated,
  }) {
    // FIX: Reset all stats including the new daysMissedIn
    if (attendanceRecords.isEmpty) {
      final workDays = _calculateWorkDaysBetween(startDate, endDate);
      onStatsCalculated(StaffStats(
        totalAttendanceDays: workDays,
        daysPresent: 0,
        daysEarlyArrival: 0,
        daysLate: 0,
        daysAbsent: workDays, // If no records, all workdays are absent
        daysMissedIn: 0,
        averageArrivalTime: '--:--',
        averageDepartureTime: '--:--',
        averageHoursWorked: 0,
        weeklyAttendanceData: List.filled(7, 0),
      ));
      return;
    }

    int workDaysCount = _calculateWorkDaysBetween(startDate, endDate);

    int daysPresent = 0;
    int daysEarlyArrival = 0;
    int daysLate = 0;
    int daysMissedIn = 0; // FIX: New counter for missed clock-ins

    int totalMinutesWorked = 0;
    int daysWithHoursCalculated = 0;
    List<int> arrivalMinutesList = [];
    List<int> departureMinutesList = [];

    for (var record in attendanceRecords) {
      final String arrivalTime = record['arrivalTime'] ?? '';
      final String departureTime = record['departureTime'] ?? '';

      // FIX: Check for 'forgotClockIn' flag first. This is a "missed in" day.
      if (record['forgotClockIn'] == true) {
        daysMissedIn++;
      } else {
        // Only if they did not forget to clock in, we count them as "present".
        daysPresent++;

        if (record['isLate'] == true) {
          daysLate++;
        }

        if (arrivalTime.isNotEmpty) {
          if (_isEarlyArrival(timeSettings, arrivalTime)) {
            daysEarlyArrival++;
          }
          arrivalMinutesList.add(parseTimeToMinutes(arrivalTime));
        }
      }

      // Hour calculation should still work even if they missed clock-in but have a clock-out
      if (arrivalTime.isNotEmpty && departureTime.isNotEmpty) {
        final int arrivalMinutes = parseTimeToMinutes(arrivalTime);
        final int departureMinutes = parseTimeToMinutes(departureTime);

        if (departureMinutes > arrivalMinutes) {
          totalMinutesWorked += (departureMinutes - arrivalMinutes);
          daysWithHoursCalculated++;
        }
        departureMinutesList.add(departureMinutes);
      }
    }

    // FIX: Absent days are total workdays minus all other categories.
    final int accountedForDays = daysPresent + daysMissedIn;
    final int absentDays = workDaysCount > accountedForDays
        ? workDaysCount - accountedForDays
        : 0;

    String averageArrivalTime = '--:--';
    if (arrivalMinutesList.isNotEmpty) {
      final int totalMinutes = arrivalMinutesList.reduce((a, b) => a + b);
      final int avgMinutes = totalMinutes ~/ arrivalMinutesList.length;
      averageArrivalTime = _formatMinutesToTime(avgMinutes);
    }

    String averageDepartureTime = '--:--';
    if (departureMinutesList.isNotEmpty) {
      final int totalMinutes = departureMinutesList.reduce((a, b) => a + b);
      final int avgMinutes = totalMinutes ~/ departureMinutesList.length;
      averageDepartureTime = _formatMinutesToTime(avgMinutes);
    }

    double averageHoursWorked = 0;
    if (daysWithHoursCalculated > 0) {
      averageHoursWorked = (totalMinutesWorked / daysWithHoursCalculated) / 60;
    }

    List<double> weeklyAttendanceData =
        _calculateWeeklyTrend(attendanceRecords);

    // FIX: Pass the new daysMissedIn value to the StaffStats object.
    onStatsCalculated(StaffStats(
      totalAttendanceDays: workDaysCount,
      daysPresent: daysPresent,
      daysEarlyArrival: daysEarlyArrival,
      daysLate: daysLate,
      daysAbsent: absentDays,
      daysMissedIn: daysMissedIn,
      averageArrivalTime: averageArrivalTime,
      averageDepartureTime: averageDepartureTime,
      averageHoursWorked: averageHoursWorked,
      weeklyAttendanceData: weeklyAttendanceData,
    ));
  }

  /// Helper method to check if an arrival time is considered early.
  static bool _isEarlyArrival(TimeSettings timeSettings, String arrivalTime) {
    if (arrivalTime.isEmpty) return false;

    final TimeOfDay lateTime = timeSettings.lateTime;
    final int expectedArrivalMinutes = lateTime.hour * 60 + lateTime.minute;
    final int actualArrivalMinutes = parseTimeToMinutes(arrivalTime);

    return actualArrivalMinutes < expectedArrivalMinutes;
  }

  /// Calculate the number of work days (Mon-Fri) between two dates.
  static int _calculateWorkDaysBetween(DateTime startDate, DateTime endDate) {
    int workDaysCount = 0;
    DateTime currentDate =
        DateTime(startDate.year, startDate.month, startDate.day);
    // FIX: Ensure the end date is inclusive and not in the future
    final now = DateTime.now();
    final effectiveEndDate = endDate.isAfter(now) ? now : endDate;
    final endDateTime = DateTime(
        effectiveEndDate.year, effectiveEndDate.month, effectiveEndDate.day);

    while (!currentDate.isAfter(endDateTime)) {
      if (currentDate.weekday >= 1 && currentDate.weekday <= 5) {
        workDaysCount++;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return workDaysCount;
  }

  /// Calculate weekly attendance trend data for charts.
  static List<double> _calculateWeeklyTrend(
      List<Map<String, dynamic>> attendanceRecords) {
    List<double> weeklyAttendanceData = List.filled(7, 0);
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));

    for (int i = 0; i < 7; i++) {
      final date = weekAgo.add(Duration(days: i));
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);

      final record = attendanceRecords.firstWhere(
          (r) => r['date'] == formattedDate,
          orElse: () => {'arrivalTime': ''});

      final arrivalTime = record['arrivalTime'] as String? ?? '';
      if (arrivalTime.isNotEmpty) {
        final arrivalMinutes = parseTimeToMinutes(arrivalTime);
        final arrivalHours = arrivalMinutes / 60.0;
        weeklyAttendanceData[i] = arrivalHours;
      }
    }

    return weeklyAttendanceData;
  }

  /// Parse time string (HH:MM) to minutes past midnight.
  static int parseTimeToMinutes(String timeString) {
    if (timeString.isEmpty) return 0;
    try {
      final parts = timeString.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      print('Error parsing time: $timeString - $e');
      return 0;
    }
  }

  /// Format minutes past midnight to time string (HH:MM).
  static String _formatMinutesToTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format time from 24h to 12h format with AM/PM.
  static String formatTimeToAmPm(String time24h) {
    if (time24h.isEmpty || time24h == '--:--') return '--:--';
    try {
      final time = DateFormat('HH:mm').parse(time24h);
      return DateFormat('h:mm a').format(time);
    } catch (e) {
      return '--:--';
    }
  }
}