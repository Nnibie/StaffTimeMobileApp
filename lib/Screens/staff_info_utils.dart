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
  /// Find the earliest date employees started clocking in and the latest date they clocked out
  static Future<Map<String, DateTime>> getAttendanceDateRange({
    required String clientPath,
  }) async {
    try {
      // Default values in case of errors
      DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
      DateTime endDate = DateTime.now();
      
      // Query for earliest record
      final earliestSnapshot = await FirebaseFirestore.instance
          .collection('$clientPath/attendance')
          .orderBy('date', descending: false)
          .limit(1)
          .get();
      
      // Query for latest record
      final latestSnapshot = await FirebaseFirestore.instance
          .collection('$clientPath/attendance')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      
      // Parse the dates if records are found
      if (earliestSnapshot.docs.isNotEmpty) {
        final firstRecord = earliestSnapshot.docs.first.data();
        final firstDateStr = firstRecord['date'] as String;
        startDate = DateFormat('yyyy-MM-dd').parse(firstDateStr);
      }
      
      if (latestSnapshot.docs.isNotEmpty) {
        final lastRecord = latestSnapshot.docs.first.data();
        final lastDateStr = lastRecord['date'] as String;
        endDate = DateFormat('yyyy-MM-dd').parse(lastDateStr);
      }
      
      // If we got here but couldn't find records, try querying by document ID patterns
      if (earliestSnapshot.docs.isEmpty || latestSnapshot.docs.isEmpty) {
        await _getDateRangeFromDocIds(clientPath, startDate, endDate);
      }
      
      return {
        'startDate': startDate,
        'endDate': endDate,
      };
    } catch (error) {
      print('Error finding attendance date range: $error');
      
      // Try alternative approach if the first attempt failed
      return _getDateRangeFromDocIds(
        clientPath, 
        DateTime.now().subtract(const Duration(days: 30)), 
        DateTime.now()
      );
    }
  }
  
  /// Alternative method to find date range from document IDs
  static Future<Map<String, DateTime>> _getDateRangeFromDocIds(
    String clientPath, 
    DateTime defaultStartDate, 
    DateTime defaultEndDate
  ) async {
    try {
      // Get all document IDs
      final querySnapshot = await FirebaseFirestore.instance
          .collection('$clientPath/attendance')
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return {
          'startDate': defaultStartDate,
          'endDate': defaultEndDate,
        };
      }
      
      // Extract dates from document IDs (format: PWASTAFF-xxxxx_yyyy-MM-dd)
      List<DateTime> dates = [];
      
      for (var doc in querySnapshot.docs) {
        String docId = doc.id;
        if (docId.contains('_')) {
          try {
            final dateStr = docId.split('_')[1];
            final date = DateFormat('yyyy-MM-dd').parse(dateStr);
            dates.add(date);
          } catch (e) {
            // Skip this document if date parsing fails
            print('Error parsing date from docId $docId: $e');
          }
        }
      }
      
      if (dates.isEmpty) {
        return {
          'startDate': defaultStartDate,
          'endDate': defaultEndDate,
        };
      }
      
      // Sort dates to find earliest and latest
      dates.sort();
      DateTime startDate = dates.first;
      DateTime endDate = dates.last;
      
      return {
        'startDate': startDate,
        'endDate': endDate,
      };
    } catch (error) {
      print('Error finding date range from document IDs: $error');
      return {
        'startDate': defaultStartDate,
        'endDate': defaultEndDate,
      };
    }
  }

  /// Calculate attendance statistics based on attendance records
  static void calculateStats({
    required List<Map<String, dynamic>> attendanceRecords,
    required TimeSettings timeSettings,
    required DateTime startDate,
    required DateTime endDate,
    required Function(StaffStats) onStatsCalculated,
  }) {
    // Create empty stats object with default values
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

    // Calculate total work days in the date range (excluding weekends)
    int workDaysCount = _calculateWorkDaysBetween(startDate, endDate);
    final int totalAttendanceDays = workDaysCount;
    
    // Initialize counters and accumulators
    int totalMinutesWorked = 0;
    int daysWithHoursCalculated = 0;
    Map<String, int> dailyArrivalTimes = {}; // For calculating averages
    Map<String, int> dailyDepartureTimes = {}; // For calculating averages
    
    // Create a map of dates for tracking attendance
    Map<String, bool> daysPresent = {};
    int daysEarlyArrival = 0; // Important: this is one of our fixes
    int daysLate = 0;
    
    // Process each record
    for (var record in attendanceRecords) {
      final String date = record['date'] as String;
      final String arrivalTime = record['arrivalTime'] as String? ?? '';
      final String departureTime = record['departureTime'] as String? ?? '';
      final bool isLate = record['isLate'] as bool? ?? false;
      final bool isActive = record['isActive'] as bool? ?? false;
      
      // Mark day as present
      daysPresent[date] = true;
      
      // FIX: Explicit check for early arrival using our helper method
      if (arrivalTime.isNotEmpty) {
        final bool isEarlyArrival = _isEarlyArrival(timeSettings, arrivalTime);
        
        // Count early arrivals and late arrivals
        if (isEarlyArrival) {
          daysEarlyArrival++; // This ensures early arrivals are properly counted
        } else if (isLate) {
          daysLate++;
        }
      }
      
      // Calculate hours worked if both arrival and departure times exist
      if (arrivalTime.isNotEmpty && departureTime.isNotEmpty && !isActive) {
        final int arrivalMinutes = _parseTimeToMinutes(arrivalTime);
        final int departureMinutes = _parseTimeToMinutes(departureTime);
        
        if (departureMinutes > arrivalMinutes) {
          final int minutesWorked = departureMinutes - arrivalMinutes;
          totalMinutesWorked += minutesWorked;
          daysWithHoursCalculated++;
        }
      }
      
      // Store arrival and departure times for average calculation
      if (arrivalTime.isNotEmpty) {
        dailyArrivalTimes[date] = _parseTimeToMinutes(arrivalTime);
      }
      
      if (departureTime.isNotEmpty && !isActive) {
        dailyDepartureTimes[date] = _parseTimeToMinutes(departureTime);
      }
    }
    
    // Calculate present days (those with records)
    final int daysCount = daysPresent.length;
    
    // Calculate absent days (total days minus present days)
    final int absentDays = totalAttendanceDays > daysCount ? totalAttendanceDays - daysCount : 0;
    
    // Default values for time stats
    String averageArrivalTime = '--:--';
    String averageDepartureTime = '--:--';
    double averageHoursWorked = 0;
    
    // Calculate average hours worked
    if (daysWithHoursCalculated > 0) {
      averageHoursWorked = totalMinutesWorked / (daysWithHoursCalculated * 60);
    }
    
    // Calculate average arrival and departure times
    if (dailyArrivalTimes.isNotEmpty) {
      final int totalArrivalMinutes = dailyArrivalTimes.values.reduce((a, b) => a + b);
      final int averageArrivalMinutes = totalArrivalMinutes ~/ dailyArrivalTimes.length;
      averageArrivalTime = _formatMinutesToTime(averageArrivalMinutes);
    }
    
    if (dailyDepartureTimes.isNotEmpty) {
      final int totalDepartureMinutes = dailyDepartureTimes.values.reduce((a, b) => a + b);
      final int averageDepartureMinutes = totalDepartureMinutes ~/ dailyDepartureTimes.length;
      averageDepartureTime = _formatMinutesToTime(averageDepartureMinutes);
    }
    
    // Calculate weekly attendance trend data
    List<double> weeklyAttendanceData = _calculateWeeklyTrend(attendanceRecords);
    
    // Return calculated stats
    onStatsCalculated(StaffStats(
      totalAttendanceDays: totalAttendanceDays,
      daysPresent: daysCount,
      daysEarlyArrival: daysEarlyArrival, // Now correctly calculated
      daysLate: daysLate,
      daysAbsent: absentDays,
      averageArrivalTime: averageArrivalTime,
      averageDepartureTime: averageDepartureTime,
      averageHoursWorked: averageHoursWorked,
      weeklyAttendanceData: weeklyAttendanceData,
    ));
  }

  /// Helper method to check if arrival is early
 static bool _isEarlyArrival(TimeSettings timeSettings, String arrivalTime) {
  if (arrivalTime.isEmpty) return false;
  
  // Get expected arrival time from timeSettings
  final int expectedArrivalMinutes = timeSettings.expectedArrivalMinutes;
  final int actualArrivalMinutes = _parseTimeToMinutes(arrivalTime);
  
  // Return true if arrived earlier than expected time
  return actualArrivalMinutes < expectedArrivalMinutes;
}
  /// Calculate the number of work days between two dates (excluding weekends)
  static int _calculateWorkDaysBetween(DateTime startDate, DateTime endDate) {
    int workDaysCount = 0;
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateTime = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!currentDate.isAfter(endDateTime)) {
      // Skip weekends (Saturday = 6, Sunday = 7)
      if (currentDate.weekday != 6 && currentDate.weekday != 7) {
        workDaysCount++;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return workDaysCount;
  }

  /// Calculate weekly attendance trend data
  static List<double> _calculateWeeklyTrend(List<Map<String, dynamic>> attendanceRecords) {
    // Initialize attendance data for each day
    List<double> weeklyAttendanceData = List.filled(7, 0);

    // Get today and 6 days ago
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));

    // Loop through the last 7 days
    for (int i = 0; i < 7; i++) {
      final date = weekAgo.add(Duration(days: i));
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);

      // Find attendance record for this date
      final record = attendanceRecords.firstWhere(
          (r) => r['date'] == formattedDate,
          orElse: () => {'arrivalTime': ''});

      // If there's an arrival time, calculate the value
      final arrivalTime = record['arrivalTime'] as String? ?? '';
      if (arrivalTime.isNotEmpty) {
        // Convert arrival time to a value (minutes past midnight)
        final arrivalMinutes = _parseTimeToMinutes(arrivalTime);

        // Convert to hours for the chart (e.g., 7.5 for 7:30 AM)
        final arrivalHours = arrivalMinutes / 60;
        weeklyAttendanceData[i] = arrivalHours;
      } else {
        // No arrival time means they were absent
        weeklyAttendanceData[i] = 0;
      }
    }

    return weeklyAttendanceData;
  }

  /// Parse time string (HH:MM) to minutes past midnight
  static int _parseTimeToMinutes(String timeString) {
    if (timeString.isEmpty) return 0;

    try {
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      return hour * 60 + minute;
    } catch (e) {
      print('Error parsing time: $timeString - $e');
      return 0;
    }
  }

  /// Format minutes past midnight to time string (HH:MM)
  static String _formatMinutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Format time from 24h to 12h format
  static String formatTimeToAmPm(String time24h) {
    try {
      if (time24h == '' || time24h == '--:--') return '--:--';

      final timeParts = time24h.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$hour12:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return '--:--';
    }
  }
}