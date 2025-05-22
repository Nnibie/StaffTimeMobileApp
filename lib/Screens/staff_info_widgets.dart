import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

/// StaffInfoWidgets provides UI components for the StaffInfo screen
class StaffInfoWidgets {
  /// Builds the staff profile card widget
  static Widget buildProfileCard(
  BuildContext context,
  String staffName,
  String? profileImageUrl,
) {
  // Get staff initials for avatar fallback
  final nameParts = staffName.split(' ');
  String initials = '';
  if (nameParts.isNotEmpty) {
    initials = nameParts.map((part) => part.isNotEmpty ? part[0] : '').join('');
  }
  
  return Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(20),
    decoration: AppTheme.cardDecoration,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
      children: [
        // Staff avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.secondaryTextColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: profileImageUrl != null && profileImageUrl.isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(profileImageUrl),
                )
              : Center(
                  child: Text(
                    initials,
                    style: AppTheme.headerLargeStyle.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
        ),
        
        const SizedBox(width: 20),
        
        // Staff info
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Take minimum vertical space needed
            crossAxisAlignment: CrossAxisAlignment.start, // Keep text left-aligned
            mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
            children: [
              Text(
                staffName,
                style: AppTheme.headerMediumStyle,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1), // Slightly increased spacing
              Text(
                'Staff',
                style: AppTheme.bodySmallStyle,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

 // Fix for buildSummaryStats
static Widget buildSummaryStats({
  required int daysEarlyArrival,
  required int daysLate,
  required int daysAbsent,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: AppTheme.cardDecoration,
    child: Row(
      children: [
        _buildStatItem(
          'Early', 
          daysEarlyArrival.toString(), 
          'days', 
          AppTheme.presentColor
        ),
        _buildVerticalDivider(),
        _buildStatItem(
          'Late', 
          daysLate.toString(), 
          'times', 
          AppTheme.lateColor
        ),
        _buildVerticalDivider(),
        _buildStatItem(
          'Absent', 
          daysAbsent.toString(), 
          'days', 
          AppTheme.absentColor
        ),
      ],
    ),
  );
}

// Helper method for the vertical divider in the summary stats
static Widget _buildVerticalDivider() {
  return Container(
    height: 40,
    width: 1,
    color: Colors.grey.withOpacity(0.3),
  );
}

/// Builds the attendance breakdown pie chart
/// Builds the attendance breakdown pie chart
// Fix for buildAttendanceBreakdownChart
static Widget buildAttendanceBreakdownChart({
  required int daysEarlyArrival,
  required int daysLate,
  required int daysAbsent,
}) {
  // Make sure we actually have some data to show
  final totalDays = daysEarlyArrival + daysLate + daysAbsent;
  
  // Only calculate percentages if we have days to show
  final double earlyPercentage = totalDays > 0 ? (daysEarlyArrival / totalDays) * 100 : 0;
  final double latePercentage = totalDays > 0 ? (daysLate / totalDays) * 100 : 0;
  final double absentPercentage = totalDays > 0 ? (daysAbsent / totalDays) * 100 : 0;
  
  // Prevent issues with pie chart if all values are zero
  final bool hasData = totalDays > 0;
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(20),
    decoration: AppTheme.cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance Breakdown',
          style: AppTheme.headerSmallStyle,
        ),
        const SizedBox(height: 5),
        Text(
          'Overview of staff attendance pattern',
          style: AppTheme.bodySmallStyle,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            // Pie chart
            SizedBox(
              height: 180,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  hasData ? PieChart(
                    PieChartData(
                      sections: [
                        // Only add sections with values > 0 to prevent chart issues
                        if (daysEarlyArrival > 0)
                          PieChartSectionData(
                            value: daysEarlyArrival.toDouble(),
                            title: '${earlyPercentage.toStringAsFixed(0)}%',
                            color: AppTheme.presentColor,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (daysLate > 0)
                          PieChartSectionData(
                            value: daysLate.toDouble(),
                            title: '${latePercentage.toStringAsFixed(0)}%',
                            color: AppTheme.lateColor,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (daysAbsent > 0)
                          PieChartSectionData(
                            value: daysAbsent.toDouble(),
                            title: '${absentPercentage.toStringAsFixed(0)}%',
                            color: AppTheme.absentColor,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                      sectionsSpace: 0,
                      centerSpaceRadius: 40,
                      startDegreeOffset: -90,
                    ),
                  ) : Center(
                    child: Text(
                      'No data',
                      style: AppTheme.bodyMediumStyle,
                    ),
                  ),
                  Text(
                    '$totalDays\nDays',
                    style: AppTheme.statsLabelStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(
                    'Early',
                    '$daysEarlyArrival days (${earlyPercentage.toStringAsFixed(0)}%)',
                    AppTheme.presentColor,
                  ),
                  const SizedBox(height: 16),
                  _buildLegendItem(
                    'Late',
                    '$daysLate days (${latePercentage.toStringAsFixed(0)}%)',
                    AppTheme.lateColor,
                  ),
                  const SizedBox(height: 16),
                  _buildLegendItem(
                    'Absent',
                    '$daysAbsent days (${absentPercentage.toStringAsFixed(0)}%)',
                    AppTheme.absentColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// Helper method for pie chart legend items
static Widget _buildLegendItem(String label, String value, Color color) {
  return Row(
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: AppTheme.bodySmallStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

  

  /// Builds the attendance tabs widget with history and performance
  /// Builds the attendance history widget
static Widget buildAttendanceTabs(
  BuildContext context,
  TabController tabController, {
  required List<Map<String, dynamic>> attendanceRecords,
  required int totalAttendanceDays,
  required int daysPresent,
  required int daysLate,
  required int daysAbsent,
  required double averageHoursWorked,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: AppTheme.cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Attendance History',
            style: AppTheme.headerSmallStyle,
          ),
        ),
        
        Container(
          height: 400,
          child: _buildAttendanceHistoryTab(attendanceRecords),
        ),
      ],
    ),
  );
}

  // Helper widgets and methods
  static Widget _buildStatItem(
      String label, String value, String subtitle, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTheme.statsLabelStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppTheme.statsNumberStyle.copyWith(color: valueColor),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: AppTheme.statsSubtitleStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  

  static Widget _buildAttendanceHistoryTab(List<Map<String, dynamic>> attendanceRecords) {
  if (attendanceRecords.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          'No attendance records found for the selected date range.',
          style: AppTheme.bodyMediumStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  return ListView.separated(
    padding: const EdgeInsets.all(15),
    itemCount: attendanceRecords.length,
    separatorBuilder: (context, index) => Divider(
      color: AppTheme.dividerColor,
      height: 1,
    ),
    itemBuilder: (context, index) {
      final record = attendanceRecords[index];
      final date = record['date'];
      
      // Get arrival time - keep normal color logic
      final String arrivalTime = record['arrivalTime'];
      final String formattedArrivalTime = _formatTimeToAmPm(arrivalTime);
      
      // For departure time
      final departureTime = record['isActive']
          ? '--:--'
          : _formatTimeToAmPm(record['departureTime']);

      // Parse date
      final DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(date);
      final String displayDate = DateFormat('E, MMM d').format(parsedDate);

      // Calculate hours worked
      String hoursWorked = '--';
      if (!record['isActive'] &&
          record['arrivalTime'].isNotEmpty &&
          record['departureTime'].isNotEmpty) {
        final arrivalMinutes = _parseTimeToMinutes(record['arrivalTime']);
        final departureMinutes = _parseTimeToMinutes(record['departureTime']);

        if (departureMinutes > arrivalMinutes) {
          final hours = (departureMinutes - arrivalMinutes) / 60;
          hoursWorked = '${hours.toStringAsFixed(1)} hrs';
        }
      }

      // Get the color for the arrival time based on status
      Color arrivalTimeColor = record['isLate'] 
          ? AppTheme.lateColor  // Red for late
          : AppTheme.presentColor;  // Green for on time
      
      // Get color for departure time - make it orange if auto-completed
      Color departureTimeColor = record['isAutoCompleted']
          ? Colors.orange  // Orange for auto-completed
          : AppTheme.primaryTextColor;  // Default text color

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date column
            Container(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayDate,
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Times column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Arrival time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'In',
                            style: AppTheme.bodySmallStyle,
                          ),
                          Text(
                            formattedArrivalTime,
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: arrivalTimeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Departure time - this will be orange if auto-completed
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Out',
                            style: AppTheme.bodySmallStyle,
                          ),
                          Text(
                            departureTime,
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: departureTimeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Hours worked
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hours',
                            style: AppTheme.bodySmallStyle,
                          ),
                          Text(
                            hoursWorked,
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Status indicators - REMOVED Auto Completed tag
                  Row(
                    children: [
                      if (record['isLate'])
                        _buildStatusTag('Late', AppTheme.lateColor),
                      if (record['isEarlyDeparture'] && !record['isActive'])
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          child: _buildStatusTag(
                              'Left Early', AppTheme.lateColor),
                        ),
                      if (record['isActive'])
                        _buildStatusTag('Active', AppTheme.activeColor),
                      // Removed the Auto Completed tag as requested
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

  static Widget _buildStatusTag(String text, Color color) {
  return Container(
    margin: const EdgeInsets.only(right: 5),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      text,
      style: AppTheme.bodySmallStyle.copyWith(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

  
  
  // Time formatting utilities
  static String _formatTimeToAmPm(String time) {
  if (time.isEmpty) return '--:--';
  
  try {
    final timeParts = time.split(':');
    if (timeParts.length < 2) return time;
    
    int hour = int.parse(timeParts[0]);
    final minute = timeParts[1];
    
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$hour:$minute $period';
  } catch (e) {
    return time;
  }
}

static int _parseTimeToMinutes(String time) {
  if (time.isEmpty) return 0;
  
  try {
    final timeParts = time.split(':');
    if (timeParts.length < 2) return 0;
    
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    
    return hour * 60 + minute;
  } catch (e) {
    return 0;
  }
}

  
}