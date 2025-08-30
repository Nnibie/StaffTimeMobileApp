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
      initials =
          nameParts.map((part) => part.isNotEmpty ? part[0] : '').join('');
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center, // Center items vertically
        children: [
          // Staff avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              // FIX: Replaced deprecated withOpacity
              color: AppTheme.secondaryTextColor.withAlpha(25),
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
              mainAxisSize:
                  MainAxisSize.min, // Take minimum vertical space needed
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Keep text left-aligned
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center content vertically
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
          _buildStatItem('Early', daysEarlyArrival.toString(), 'days',
              AppTheme.presentColor),
          _buildVerticalDivider(),
          _buildStatItem(
              'Late', daysLate.toString(), 'times', AppTheme.lateColor),
          _buildVerticalDivider(),
          _buildStatItem(
              'Absent', daysAbsent.toString(), 'days', AppTheme.absentColor),
        ],
      ),
    );
  }

// Helper method for the vertical divider in the summary stats
  static Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      // FIX: Replaced deprecated withOpacity
      color: Colors.grey.withAlpha(77),
    );
  }

  /// Builds the attendance breakdown pie chart
  static Widget buildAttendanceBreakdownChart({
    required int totalDays, // MODIFIED: Use the total workdays count
    required int daysEarlyArrival,
    required int daysLate,
    required int daysAbsent,
    required int daysMissedIn, // MODIFIED: Added for missed clock-ins
  }) {
    // FIX: The total for percentage calculation now includes all categories.
    final totalForPercentage =
        daysEarlyArrival + daysLate + daysAbsent + daysMissedIn;

    // Only calculate percentages if we have days to show
    final double earlyPercentage = totalForPercentage > 0
        ? (daysEarlyArrival / totalForPercentage) * 100
        : 0;
    final double latePercentage =
        totalForPercentage > 0 ? (daysLate / totalForPercentage) * 100 : 0;
    final double absentPercentage =
        totalForPercentage > 0 ? (daysAbsent / totalForPercentage) * 100 : 0;
    final double missedInPercentage = totalForPercentage > 0
        ? (daysMissedIn / totalForPercentage) * 100
        : 0; // MODIFIED: Calculate percentage for missed-ins

    // Prevent issues with pie chart if all values are zero
    final bool hasData = totalForPercentage > 0;
    final Color missedInColor = Colors.orange.shade700; // MODIFIED: Define color for missed-in

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
                    hasData
                        ? PieChart(
                            PieChartData(
                              sections: [
                                // Early Arrival
                                if (daysEarlyArrival > 0)
                                  PieChartSectionData(
                                    value: daysEarlyArrival.toDouble(),
                                    title:
                                        '${earlyPercentage.toStringAsFixed(0)}%',
                                    color: AppTheme.presentColor,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                // Late Arrival
                                if (daysLate > 0)
                                  PieChartSectionData(
                                    value: daysLate.toDouble(),
                                    title:
                                        '${latePercentage.toStringAsFixed(0)}%',
                                    color: AppTheme.lateColor,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                // Absent
                                if (daysAbsent > 0)
                                  PieChartSectionData(
                                    value: daysAbsent.toDouble(),
                                    title:
                                        '${absentPercentage.toStringAsFixed(0)}%',
                                    color: AppTheme.absentColor,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                // MODIFIED: New section for Missed In
                                if (daysMissedIn > 0)
                                  PieChartSectionData(
                                    value: daysMissedIn.toDouble(),
                                    title:
                                        '${missedInPercentage.toStringAsFixed(0)}%',
                                    color: missedInColor,
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
                          )
                        : Center(
                            child: Text(
                              'No data',
                              style: AppTheme.bodyMediumStyle,
                            ),
                          ),
                    // FIX: The text in the center now uses the correct total workdays count.
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
                    // MODIFIED: New legend item for Missed In
                    _buildLegendItem(
                      'No Clock In',
                      '$daysMissedIn days (${missedInPercentage.toStringAsFixed(0)}%)',
                      missedInColor,
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
  static Widget buildAttendanceTabs(
    BuildContext context,
    TabController tabController, {
    required List<Map<String, dynamic>> attendanceRecords,
    required int totalAttendanceDays,
    required int daysPresent,
    required int daysLate,
    required int daysAbsent,
    required double averageHoursWorked,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    // FIX: Removed the outer Container with AppTheme.cardDecoration to prevent a "card-in-a-card" look.
    // This Column now directly organizes the title and the list of weekly attendance cards.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The "Attendance History" title, with padding to align it with other elements.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Attendance History',
            style: AppTheme.headerSmallStyle,
          ),
        ),
        // The history tab widget is now called directly. 
        // The fixed-height SizedBox was removed to allow the list to dynamically size itself.
        _buildAttendanceHistoryTab(
          attendanceRecords,
          startDate,
          endDate,
        ),
      ],
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

// Helper method to determine the week an entry belongs to, relative to the current week.
  static int _getWeekIdentifier(DateTime date, DateTime now) {
    // Normalize dates to midnight to ensure consistent day calculations.
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    DateTime normalizedNow = DateTime(now.year, now.month, now.day);
    
    // Determine the start of the week (Monday) for both the target date and the current date.
    DateTime startOfThisWeek =
        normalizedNow.subtract(Duration(days: normalizedNow.weekday - 1));
    DateTime startOfTargetWeek =
        normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
        
    // Calculate the difference in days and convert to a whole number of weeks.
    int differenceInDays = startOfThisWeek.difference(startOfTargetWeek).inDays;
    return (differenceInDays / 7).floor();
  }

  // Helper method to get the title for a week based on its identifier.
  static String _getWeekHeaderTitle(int weekId) {
    if (weekId == 0) return 'This Week';
    if (weekId == 1) return 'Last Week';
    // For older weeks, display a dynamic title like "3 Weeks Ago".
    return '${weekId + 1} Weeks Ago';
  }

  // The refactored build method for the attendance history tab.
  static Widget _buildAttendanceHistoryTab(
      List<Map<String, dynamic>> attendanceRecords,
      DateTime startDate,
      DateTime endDate) {
    // Create a quick-lookup map for attendance records by their date string.
    final recordsByDate = {
      for (var record in attendanceRecords) record['date']: record
    };

    final now = DateTime.now();
    // Ensure the end date for the list is not in the future.
    final effectiveEndDate = endDate.isAfter(now) ? now : endDate;

    final dayCount = effectiveEndDate.difference(startDate).inDays + 1;
    // If the date range is invalid, show a message.
    if (dayCount <= 0) {
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

    // Generate a list of all dates within the effective range.
    final allDates = List.generate(
        dayCount, (i) => effectiveEndDate.subtract(Duration(days: i)));

    // Group the dates by week, excluding non-workdays (weekends).
    final Map<int, List<DateTime>> groupedByWeek = {};
    for (var date in allDates) {
      // Skip weekends as they are not considered workdays.
      if (date.weekday == 6 || date.weekday == 7) continue;

      final weekId = _getWeekIdentifier(date, now);
      if (groupedByWeek[weekId] == null) {
        groupedByWeek[weekId] = [];
      }
      groupedByWeek[weekId]!.add(date);
    }

    // Sort the weeks chronologically.
    final sortedWeeks = groupedByWeek.keys.toList()..sort((a, b) => a.compareTo(b));

    // Build the list of weekly attendance cards.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sortedWeeks.length,
      itemBuilder: (context, index) {
        final weekId = sortedWeeks[index];
        final datesInWeek = groupedByWeek[weekId]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly header (e.g., "This Week").
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
              child: Text(
                _getWeekHeaderTitle(weekId).toUpperCase(),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryTextColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // The card containing the attendance records for the week.
            Container(
              decoration: AppTheme.cardDecoration,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: datesInWeek.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppTheme.dividerColor,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final date = datesInWeek[index];
                  final formattedDate = DateFormat('yyyy-MM-dd').format(date);
                  final record = recordsByDate[formattedDate];
                  final displayDate = _getRelativeDateString(date);

                  if (record != null) {
                    final bool forgotClockIn = record['forgotClockIn'] ?? false;

                    // Display an "incomplete" tile for missed clock-ins.
                    if (forgotClockIn) {
                      return _buildIncompleteRecordTile(
                        displayDate: displayDate,
                        status: 'Missed In',
                        departureTime:
                            _formatTimeToAmPm(record['departureTime'] ?? ''),
                      );
                    }
                    // For all other present cases, use the standard "present" tile.
                    else {
                      return _buildPresentTile(displayDate, record);
                    }
                  } else {
                    // If no record exists for a workday, mark it as "Absent".
                    return _buildAbsentTile(displayDate);
                  }
                },
              ),
            ),
            const SizedBox(height: 24), // Space between weekly cards
          ],
        );
      },
    );
  }

  static Widget _buildStatusTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(77)),
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

  static Widget _buildTileRow({
    required String date,
    required IconData icon,
    required Color iconColor,
    required Widget statusWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              date,
              style: AppTheme.bodyMediumStyle
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 16),
          Expanded(child: statusWidget),
        ],
      ),
    );
  }

  static Widget _buildPresentTile(
      String displayDate, Map<String, dynamic> record) {
    // --- 1. Get all the possible states from the processed record ---
    final String arrivalTime =
        _formatTimeToAmPm(record['arrivalTime'] ?? '--:--');
    final bool isLate = record['isLate'] ?? false;
    final bool isEarly = record['isEarly'] ?? false; // <-- Our new flag
    final bool isActive = record['isActive'] ?? false;
    final bool isEarlyDeparture = record['isEarlyDeparture'] ?? false;
    final bool missedClockOut = record['missedClockOut'] ?? false;

    // --- 2. Determine the correct icon and color for the entire row ---
    final IconData tileIcon;
    final Color tileIconColor;

    if (missedClockOut) {
      // Use warning icon for missed clock-outs
      tileIcon = Icons.error_outline;
      tileIconColor = Colors.orange.shade700;
    } else {
      // Use standard checkmark for all other present states
      tileIcon = Icons.check_circle_outline;
      tileIconColor = AppTheme.presentColor;
    }

    // --- 3. Conditionally create the widget for the departure time ---
    Widget departureWidget;

    if (missedClockOut) {
      // FIX: Use shorter text to prevent overflow
      departureWidget = Text(
        'No Out',
        style: AppTheme.bodyMediumStyle.copyWith(
          fontWeight: FontWeight.w500,
          color: Colors.orange.shade700, // A distinct warning color
          fontSize: 13, // Slightly smaller to guarantee fit
        ),
      );
    } else if (isActive) {
      departureWidget = Text('--:--',
          style: AppTheme.bodyMediumStyle
              .copyWith(fontWeight: FontWeight.bold));
    } else {
      final String departureTime =
          _formatTimeToAmPm(record['departureTime'] ?? '--:--');
      departureWidget = Text(departureTime,
          style: AppTheme.bodyMediumStyle
              .copyWith(fontWeight: FontWeight.bold));
    }

    // --- 4. Build the final tile ---
    return _buildTileRow(
      date: displayDate,
      icon: tileIcon, // Use our dynamic icon
      iconColor: tileIconColor, // Use our dynamic color
      statusWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The Arrival Time is now colored green for early, red for late
              Text(
                arrivalTime,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLate
                      ? AppTheme.lateColor
                      : (isEarly
                          ? AppTheme.presentColor
                          : AppTheme.primaryTextColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.arrow_forward,
                    size: 16, color: AppTheme.secondaryTextColor),
              ),
              // Use an Expanded widget to prevent overflow with the departure text
              Expanded(
                child: departureWidget,
              ),
            ],
          ),
          // A separate row for extra status tags
          if (isEarlyDeparture || isActive)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  if (isEarlyDeparture)
                    _buildStatusTag('Left Early', AppTheme.lateColor),
                  if (isActive) _buildStatusTag('Active', AppTheme.activeColor),
                ],
              ),
            ),
        ],
      ),
    );
  }

// NEW: An intuitive tile for days the employee was absent.
  static Widget _buildAbsentTile(String displayDate) {
    return _buildTileRow(
      date: displayDate,
      icon: Icons.cancel_outlined,
      iconColor: AppTheme.absentColor,
      statusWidget: Text(
        'Absent',
        style: AppTheme.bodyMediumStyle.copyWith(
          color: AppTheme.absentColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static Widget _buildIncompleteRecordTile({
    required String displayDate,
    required String status,
    String? arrivalTime,
    String? departureTime,
  }) {
    final color = Colors.orange.shade700; // A distinct warning color
    String timeInfo = '';

    // This logic now correctly handles both cases:
    // - If it's a "Missed In", it will show the departureTime.
    // - If it's a "Missed Out", it will show the arrivalTime.
    if (departureTime != null &&
        departureTime.isNotEmpty &&
        departureTime != '--:--') {
      timeInfo = 'Out: $departureTime';
    } else if (arrivalTime != null &&
        arrivalTime.isNotEmpty &&
        arrivalTime != '--:--') {
      timeInfo = 'In: $arrivalTime';
    }

    return _buildTileRow(
      date: displayDate,
      icon: Icons.error_outline, // The warning icon
      iconColor: color,
      statusWidget: Row(
        children: [
          // Displays "Missed In" or "Missed Out"
          Text(
            status,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Displays "In: 9:00 AM" or "Out: 5:00 PM"
          Text(
            timeInfo,
            style:
                AppTheme.bodySmallStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static String _getRelativeDateString(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) {
      return 'Today';
    } else if (dateToCompare == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('E, MMM d').format(date);
    }
  }
}