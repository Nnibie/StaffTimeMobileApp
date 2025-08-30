import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:shimmer/shimmer.dart';

import 'staff_info_widgets.dart';
import 'staff_info_utils.dart';
import 'package:staff_time/Widgets/date_range_selector.dart';

class StaffInfo extends StatefulWidget {
  final String clientId;
  final String staffId;
  final String staffName;
  final String? profileImageUrl;

  const StaffInfo({
    Key? key,
    required this.clientId,
    required this.staffId,
    required this.staffName,
    this.profileImageUrl,
  }) : super(key: key);

  @override
  State<StaffInfo> createState() => _StaffInfoState();
}

class _StaffInfoState extends State<StaffInfo>
    with SingleTickerProviderStateMixin {
  // Data for the employee
  List<Map<String, dynamic>> attendanceRecords = [];
  bool isLoading = true;
  bool _isMounted = true; // Flag to track if widget is mounted

  // Time settings instance
  final TimeSettings _timeSettings = TimeSettings();

  // Date range for records
  DateTime? employeeStartDate;
  DateTime endDate = DateTime.now();
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  String currentDateRange = 'This Week';

  // Stats calculated from attendance records
  int totalAttendanceDays = 0;
  int daysPresent = 0;
  int daysEarlyArrival = 0;
  int daysLate = 0;
  int daysAbsent = 0;
  int daysMissedIn = 0; // MODIFIED: Added state for missed clock-ins
  String averageArrivalTime = '--:--';
  String averageDepartureTime = '--:--';
  double averageHoursWorked = 0;

  // Weekly trend data
  List<double> weeklyAttendanceData = List.filled(7, 0);
  List<String> weekdayNames = [];

  // Tab controller
  late TabController _tabController;

  // Firestore path constants

  // MODIFIED: Pointing to the correct collection
  final String _attendanceCollection = 'attendance_test';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set default 'This Week' date range
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysFromMonday));

    _initializeTimeSettings();
  }

  void _setupWeekdayNames() {
    final now = DateTime.now();
    final currentWeekday = now.weekday;

    // Get the dates for the last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: currentWeekday - 1 + (6 - i)));
      weekdayNames.add(DateFormat('E').format(date));
    }
  }

  Future<void> _initializeTimeSettings() async {
    await _timeSettings.init(widget.clientId);
    if (!_isMounted) return;

    // This now fetches the employee's registration date.
    await _findEmployeeStartDate();
    if (!_isMounted) return;

    _setupWeekdayNames();
    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _isMounted = false;
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _findEmployeeStartDate() async {
    try {
      // FIX 3: Use the dynamic widget.clientId to build the path
      final userDocPath = 'Clients/${widget.clientId}/users/${widget.staffId}';

      final userDoc = await FirebaseFirestore.instance.doc(userDocPath).get();

      if (!_isMounted) return;

      if (userDoc.exists) {
        final data = userDoc.data();
        final createdAtTimestamp = data?['createdAt'] as Timestamp?;

        if (createdAtTimestamp != null) {
          final registrationDate = createdAtTimestamp.toDate();
          setState(() {
            employeeStartDate = registrationDate;

            if (employeeStartDate!.isAfter(startDate)) {
              startDate = employeeStartDate!;
              currentDateRange =
                  'Since ${DateFormat('MMM d, yyyy').format(employeeStartDate!)}';
            }
          });
        }
      }
    } catch (error) {
      print('Error finding employee registration date: $error');
    }
  }

  Future<void> _fetchAttendanceData() async {
    if (!_isMounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDate);

      // FIX 4: Use the dynamic widget.clientId to build the collection path
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Clients/${widget.clientId}/$_attendanceCollection')
          .where('userId', isEqualTo: widget.staffId)
          .where('role', isEqualTo: 'staff')
          .where('date', isGreaterThanOrEqualTo: formattedStartDate)
          .where('date', isLessThanOrEqualTo: formattedEndDate)
          .orderBy('date', descending: true)
          .get();

      if (!_isMounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        _processQueryResults(querySnapshot.docs);
      } else {
        attendanceRecords = [];
        _resetStatistics();
      }

      if (_isMounted) {
        _calculateStatistics();
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      print('--- ERROR fetching attendance data ---: $error');
      if (_isMounted) {
        setState(() {
          isLoading = false;
          attendanceRecords = [];
          _resetStatistics();
        });
      }
    }
  }

  void _processQueryResults(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (!_isMounted) return;

    String formatTimestamp(Timestamp? timestamp) {
      if (timestamp == null) return '';
      return DateFormat('HH:mm').format(timestamp.toDate());
    }

    final String todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());

    attendanceRecords = docs.map((doc) {
      final data = doc.data();
      final Timestamp? clockInTimestamp = data['clockIn'] as Timestamp?;
      final Timestamp? clockOutTimestamp = data['clockOut'] as Timestamp?;

      final String status = data['status'] ?? '';
      final String dateString = data['date'] ?? '';
      final String arrivalTime = formatTimestamp(clockInTimestamp);
      final String departureTime = formatTimestamp(clockOutTimestamp);

      final bool missedClockOut =
          status == 'FORGOT_CLOCK_OUT' && dateString != todayString;

      final bool isActive =
          arrivalTime.isNotEmpty && departureTime.isEmpty && !missedClockOut;

      final bool isLate =
          arrivalTime.isNotEmpty && _timeSettings.isTimeLate(arrivalTime);

      final TimeOfDay lateTime = _timeSettings.lateTime;
      final int expectedArrivalMinutes = lateTime.hour * 60 + lateTime.minute;
      final int actualArrivalMinutes =
          StaffInfoUtils.parseTimeToMinutes(arrivalTime);
      final bool isEarly =
          arrivalTime.isNotEmpty && actualArrivalMinutes < expectedArrivalMinutes;

      // MODIFIED: 'forgotClockIn' is now true if there is no arrival time,
      // which is the key for detecting "missed in" days.
      final bool forgotClockIn = arrivalTime.isEmpty;
      final isEarlyDeparture = departureTime.isNotEmpty &&
          _timeSettings.isEarlyDeparture(departureTime);

      return {
        'id': doc.id,
        'staffId': data['userId'] ?? widget.staffId,
        'arrivalTime': arrivalTime,
        'departureTime': departureTime,
        'date': dateString,
        'isLate': isLate,
        'isEarly': isEarly,
        'forgotClockIn': forgotClockIn,
        'isActive': isActive,
        'isEarlyDeparture': isEarlyDeparture,
        'missedClockOut': missedClockOut,
      };
    }).toList();
  }

  void _calculateStatistics() {
    if (!_isMounted) return;

    // FIX: Always calculate stats, even for empty records, to get correct absent days.
    StaffInfoUtils.calculateStats(
      attendanceRecords: attendanceRecords,
      timeSettings: _timeSettings,
      startDate: startDate,
      endDate: endDate,
      onStatsCalculated: (stats) {
        if (_isMounted) {
          setState(() {
            totalAttendanceDays = stats.totalAttendanceDays;
            daysPresent = stats.daysPresent;
            daysLate = stats.daysLate;
            daysAbsent = stats.daysAbsent;
            daysMissedIn = stats.daysMissedIn; // MODIFIED: Update new state
            daysEarlyArrival = stats.daysEarlyArrival;
            averageArrivalTime = stats.averageArrivalTime;
            averageDepartureTime = stats.averageDepartureTime;
            averageHoursWorked = stats.averageHoursWorked;
            weeklyAttendanceData = stats.weeklyAttendanceData;
          });
        }
      },
    );
  }

  void _resetStatistics() {
    if (!_isMounted) return;

    setState(() {
      totalAttendanceDays = 0;
      daysPresent = 0;
      daysLate = 0;
      daysAbsent = 0;
      daysMissedIn = 0; // MODIFIED: Reset new state
      daysEarlyArrival = 0;
      averageArrivalTime = '--:--';
      averageDepartureTime = '--:--';
      averageHoursWorked = 0;
      weeklyAttendanceData = List.filled(7, 0);
    });
  }

  void _changeDateRange(String range) async {
    if (!_isMounted) return;

    final now = DateTime.now();
    DateTime newStartDate;
    DateTime newEndDate = now;
    String newRangeLabel = range;

    switch (range) {
      case 'Today':
        newStartDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        final daysFromMonday = now.weekday - 1;
        newStartDate = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));
        break;
      case 'This Month':
        newStartDate = DateTime(now.year, now.month, 1);
        break;
      case 'Last 30 Days':
        newStartDate = now.subtract(const Duration(days: 30));
        break;
      case 'All Time':
        newStartDate =
            employeeStartDate ?? DateTime(now.year - 1, now.month, now.day);
        newRangeLabel =
            'Since ${DateFormat('MMM d, yyyy').format(newStartDate)}';
        break;
      case 'Custom':
        final DateTimeRange? pickedRange = await showDateRangePicker(
          context: context,
          firstDate:
              employeeStartDate ?? DateTime(now.year - 2, now.month, now.day),
          lastDate: now,
          initialDateRange: DateTimeRange(
            start: startDate,
            end: endDate,
          ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );

        if (!_isMounted) return;

        if (pickedRange != null) {
          newStartDate = pickedRange.start;
          newEndDate = pickedRange.end;
          newRangeLabel =
              '${DateFormat('MMM d').format(newStartDate)} - ${DateFormat('MMM d, yyyy').format(newEndDate)}';
        } else {
          return;
        }
        break;
      default:
        newStartDate = now.subtract(const Duration(days: 30));
    }

    if (_isMounted) {
      setState(() {
        startDate = newStartDate;
        endDate = newEndDate;
        currentDateRange = newRangeLabel;
      });

      _fetchAttendanceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Staff Information',
          style: AppTheme.headerMediumStyle,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppTheme.primaryColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? _buildLoadingState()
            : RefreshIndicator(
                onRefresh: () async {
                  await _initializeTimeSettings();
                },
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DateRangeSelector(
                        employeeStartDate: employeeStartDate,
                        currentStartDate: startDate,
                        currentEndDate: endDate,
                        currentDateRange: currentDateRange,
                        onRangeSelected: _changeDateRange,
                      ),
                      const SizedBox(height: 16),
                      StaffInfoWidgets.buildProfileCard(
                        context,
                        widget.staffName,
                        widget.profileImageUrl,
                      ),
                      const SizedBox(height: 16),
                      StaffInfoWidgets.buildSummaryStats(
                        daysEarlyArrival: daysEarlyArrival,
                        daysLate: daysLate,
                        daysAbsent: daysAbsent,
                      ),
                      const SizedBox(height: 20),
                      // FIX: Pass the new daysMissedIn and the correct totalAttendanceDays
                      // to the pie chart widget.
                      StaffInfoWidgets.buildAttendanceBreakdownChart(
                        totalDays: totalAttendanceDays,
                        daysEarlyArrival: daysEarlyArrival,
                        daysLate: daysLate,
                        daysAbsent: daysAbsent,
                        daysMissedIn: daysMissedIn,
                      ),
                      const SizedBox(height: 20),
                      StaffInfoWidgets.buildAttendanceTabs(
                        context,
                        _tabController,
                        attendanceRecords: attendanceRecords,
                        totalAttendanceDays: totalAttendanceDays,
                        daysPresent: daysPresent,
                        daysLate: daysLate,
                        daysAbsent: daysAbsent,
                        averageHoursWorked: averageHoursWorked,
                        startDate: startDate,
                        endDate: endDate,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              height: 45,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}