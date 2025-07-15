import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/utility/time_settings.dart';

class StaffStats {
  final int totalAttendanceDays;
  final int daysPresent;
  final int daysEarlyArrival;
  final int daysLate;
  final int daysAbsent;
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
    // If there are no records, return an empty stats object.
    if (attendanceRecords.isEmpty) {
      onStatsCalculated(StaffStats(
        totalAttendanceDays: 0,
        daysPresent: 0,
        daysEarlyArrival: 0,
        daysLate: 0,
        daysAbsent: 0,
        averageArrivalTime: '--:--',
        averageDepartureTime: '--:--',
        averageHoursWorked: 0,
        weeklyAttendanceData: List.filled(7, 0),
      ));
      return;
    }

    // Calculate the total number of working days in the selected date range.
    int workDaysCount = _calculateWorkDaysBetween(startDate, endDate);
    
    // Initialize counters and accumulators.
    int daysPresent = attendanceRecords.length;
    int daysEarlyArrival = 0;
    int daysLate = 0;
    
    int totalMinutesWorked = 0;
    int daysWithHoursCalculated = 0;
    List<int> arrivalMinutesList = [];
    List<int> departureMinutesList = [];

    // Process each record to calculate detailed stats.
    for (var record in attendanceRecords) {
      final String arrivalTime = record['arrivalTime'] ?? '';
      final String departureTime = record['departureTime'] ?? '';
      
      // A day is only 'Late' if the flag is explicitly true.
      if (record['isLate'] == true) {
        daysLate++;
      }
      
      // A day is 'Early' if there's an arrival time and it's before the expected time.
      if (arrivalTime.isNotEmpty) {
        if (_isEarlyArrival(timeSettings, arrivalTime)) {
          daysEarlyArrival++;
        }
        arrivalMinutesList.add(_parseTimeToMinutes(arrivalTime));
      }

      // Calculate hours worked only if both arrival and departure times are available.
      if (arrivalTime.isNotEmpty && departureTime.isNotEmpty) {
        final int arrivalMinutes = _parseTimeToMinutes(arrivalTime);
        final int departureMinutes = _parseTimeToMinutes(departureTime);
        
        if (departureMinutes > arrivalMinutes) {
          totalMinutesWorked += (departureMinutes - arrivalMinutes);
          daysWithHoursCalculated++;
        }
        departureMinutesList.add(departureMinutes);
      }
    }
    
    // Calculate absent days.
    final int absentDays = workDaysCount > daysPresent ? workDaysCount - daysPresent : 0;
    
    // Calculate average times and hours.
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
    
    // Calculate weekly trend data for charts.
    List<double> weeklyAttendanceData = _calculateWeeklyTrend(attendanceRecords);
    
    // Return the final calculated stats.
    onStatsCalculated(StaffStats(
      totalAttendanceDays: workDaysCount,
      daysPresent: daysPresent,
      daysEarlyArrival: daysEarlyArrival,
      daysLate: daysLate,
      daysAbsent: absentDays,
      averageArrivalTime: averageArrivalTime,
      averageDepartureTime: averageDepartureTime,
      averageHoursWorked: averageHoursWorked,
      weeklyAttendanceData: weeklyAttendanceData,
    ));
  }

  /// Helper method to check if an arrival time is considered early.
  static bool _isEarlyArrival(TimeSettings timeSettings, String arrivalTime) {
    if (arrivalTime.isEmpty) return false;
  
    final int expectedArrivalMinutes = timeSettings.expectedArrivalMinutes;
    final int actualArrivalMinutes = _parseTimeToMinutes(arrivalTime);
  
    // It's an early arrival if it's before the official start time.
    return actualArrivalMinutes < expectedArrivalMinutes;
  }

  /// Calculate the number of work days (Mon-Fri) between two dates.
  static int _calculateWorkDaysBetween(DateTime startDate, DateTime endDate) {
    int workDaysCount = 0;
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateTime = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!currentDate.isAfter(endDateTime)) {
      // Monday to Friday are weekdays (1 to 5).
      if (currentDate.weekday >= 1 && currentDate.weekday <= 5) {
        workDaysCount++;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return workDaysCount;
  }

  /// Calculate weekly attendance trend data for charts.
  static List<double> _calculateWeeklyTrend(List<Map<String, dynamic>> attendanceRecords) {
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
        final arrivalMinutes = _parseTimeToMinutes(arrivalTime);
        final arrivalHours = arrivalMinutes / 60.0;
        weeklyAttendanceData[i] = arrivalHours;
      }
    }

    return weeklyAttendanceData;
  }

  /// Parse time string (HH:MM) to minutes past midnight.
  static int _parseTimeToMinutes(String timeString) {
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