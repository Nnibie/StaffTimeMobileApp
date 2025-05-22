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
  final String staffId;
  final String staffName;
  final String? profileImageUrl;

  const StaffInfo({
    Key? key,
    required this.staffId,
    required this.staffName,
    this.profileImageUrl,
  }) : super(key: key);

  @override
  State<StaffInfo> createState() => _StaffInfoState();
}

class _StaffInfoState extends State<StaffInfo>
    with SingleTickerProviderStateMixin {
  int daysEarlyArrival = 0;
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

  // Staff ID format from Firestore (for document queries)
  late String _staffIdPrefix;

  // Stats calculated from attendance records
  int totalAttendanceDays = 0;
  int daysPresent = 0;
  int daysLate = 0;
  int daysAbsent = 0;
  String averageArrivalTime = '--:--';
  String averageDepartureTime = '--:--';
  double averageHoursWorked = 0;
  

  // Weekly trend data
  List<double> weeklyAttendanceData = List.filled(7, 0);
  List<String> weekdayNames = [];

  // Tab controller
  late TabController _tabController;

  // Firestore path constants
  final String _clientPath = 'Clients/PWA';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _staffIdPrefix = _extractStaffIdPrefix(widget.staffId);
    
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
    await _timeSettings.init();
    if (!_isMounted) return; // Check if still mounted before proceeding
    
    await _findEmployeeStartDate();
    if (!_isMounted) return; // Check again after async operation
    
    _setupWeekdayNames();
    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _isMounted = false; // Set flag to false when disposing
    _tabController.dispose();
    super.dispose();
  }

  // Extract the base staff ID prefix used in document IDs
  String _extractStaffIdPrefix(String staffId) {
    // Assuming the document ID format is like "PWASTAFF-456db952-0d43-44_2025-05-15"
    // We need to extract "PWASTAFF-456db952-0d43-44" part
    if (staffId.contains('_')) {
      return staffId.split('_')[0];
    }
    return staffId; // Return as is if no underscore found
  }

  Future<void> _findEmployeeStartDate() async {
    try {
      // Query the first attendance record for this staff member
      final querySnapshot = await FirebaseFirestore.instance
          .collection('$_clientPath/attendance')
          .where('staff_id', isEqualTo: widget.staffId)
          .orderBy('date', descending: false)
          .limit(1)
          .get();

      if (!_isMounted) return; // Check if still mounted before updating state

      if (querySnapshot.docs.isNotEmpty) {
        final firstRecord = querySnapshot.docs.first.data();
        final firstDate = firstRecord['date'] as String;
        employeeStartDate = DateFormat('yyyy-MM-dd').parse(firstDate);

        // Check if the employee started after the current startDate (This Week)
        // If so, we need to adjust the default range to start from their start date
        if (employeeStartDate!.isAfter(startDate)) {
          if (_isMounted) {
            setState(() {
              startDate = employeeStartDate!;
              currentDateRange =
                  'Since ${DateFormat('MMM d, yyyy').format(employeeStartDate!)}';
            });
          }
        }

        print(
            'Employee first record date: ${DateFormat('yyyy-MM-dd').format(employeeStartDate!)}');
      } else {
        // If no records found, try alternative query by document ID pattern
        await _findEmployeeStartDateByDocId();
      }
    } catch (error) {
      print('Error finding employee start date: $error');
      // Try alternative method if the first one fails
      if (_isMounted) {
        await _findEmployeeStartDateByDocId();
      }
    }
  }

  // Alternative method to find employee start date based on document ID patterns
  Future<void> _findEmployeeStartDateByDocId() async {
    if (!_isMounted) return; // Check if mounted
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('$_clientPath/attendance')
          .where(FieldPath.documentId,
              isGreaterThanOrEqualTo: '$_staffIdPrefix')
          .where(FieldPath.documentId,
              isLessThanOrEqualTo: '$_staffIdPrefix\uf8ff')
          .orderBy(FieldPath.documentId)
          .limit(1)
          .get();

      if (!_isMounted) return; // Check again after async operation

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        // Extract date from document ID (assuming format like PWASTAFF-456db952-0d43-44_2025-05-15)
        if (docId.contains('_')) {
          final dateStr = docId.split('_')[1];
          try {
            employeeStartDate = DateFormat('yyyy-MM-dd').parse(dateStr);

            // Check if the employee started after the current startDate (This Week)
            // If so, we need to adjust the default range to start from their start date
            if (employeeStartDate!.isAfter(startDate)) {
              if (_isMounted) {
                setState(() {
                  startDate = employeeStartDate!;
                  currentDateRange =
                      'Since ${DateFormat('MMM d, yyyy').format(employeeStartDate!)}';
                });
              }
            }

            print(
                'Employee first record date (from doc ID): ${DateFormat('yyyy-MM-dd').format(employeeStartDate!)}');
          } catch (e) {
            print('Error parsing date from docId: $e');
          }
        }
      }
    } catch (error) {
      print('Error finding employee start date by doc ID: $error');
    }
  }

  Future<void> _fetchAttendanceData() async {
    if (!_isMounted) return; // Early return if not mounted
    
    setState(() {
      isLoading = true;
    });

    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDate);
      attendanceRecords = [];

      // Method 1: Try querying by staff_id field
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('$_clientPath/attendance')
            .where('staff_id', isEqualTo: widget.staffId)
            .where('date', isGreaterThanOrEqualTo: formattedStartDate)
            .where('date', isLessThanOrEqualTo: formattedEndDate)
            .orderBy('date', descending: true)
            .get();

        if (!_isMounted) return; // Check after async operation

        if (querySnapshot.docs.isNotEmpty) {
          _processQueryResults(querySnapshot.docs);
        } else {
          // If no records found with direct query, try Method 2
          await _fetchAttendanceByDocumentId(
              formattedStartDate, formattedEndDate);
        }
      } catch (error) {
        print('Error in primary fetch method: $error');
        // Fallback to Method 2 if Method 1 fails
        if (_isMounted) {
          await _fetchAttendanceByDocumentId(
              formattedStartDate, formattedEndDate);
        }
      }

      // Calculate statistics regardless of which method worked
      if (_isMounted) {
        _calculateStatistics();

        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching attendance data: $error');
      if (_isMounted) {
        setState(() {
          isLoading = false;
          // Reset statistics when fetch fails
          _resetStatistics();
        });
      }
    }
  }

  // Method 2: Alternative way to fetch attendance by querying document IDs
  Future<void> _fetchAttendanceByDocumentId(
      String formattedStartDate, String formattedEndDate) async {
    if (!_isMounted) return; // Early return if not mounted
    
    try {
      // Create a list of possible document IDs for the date range
      List<String> possibleDocIds = [];
      DateTime current = startDate;

      while (!current.isAfter(endDate)) {
        String formattedDate = DateFormat('yyyy-MM-dd').format(current);
        String docId = '${_staffIdPrefix}_$formattedDate';
        possibleDocIds.add(docId);
        current = current.add(const Duration(days: 1));
      }

      // Fetch documents one by one or in batches
      List<QueryDocumentSnapshot<Map<String, dynamic>>> foundDocs = [];

      // Option 1: One by one approach for smaller date ranges
      if (possibleDocIds.length <= 30) {
        for (String docId in possibleDocIds) {
          if (!_isMounted) return; // Check in loop to exit early
          
          final docSnapshot = await FirebaseFirestore.instance
              .collection('$_clientPath/attendance')
              .doc(docId)
              .get();

          if (docSnapshot.exists) {
            foundDocs.add(
                docSnapshot as QueryDocumentSnapshot<Map<String, dynamic>>);
          }
        }
      }
      // Option 2: Batch approach for larger date ranges using 'in' query if supported
      else {
        // Get documents in batches since Firestore limits 'in' queries to 10 items
        for (int i = 0; i < possibleDocIds.length; i += 10) {
          if (!_isMounted) return; // Check in loop to exit early
          
          final end =
              (i + 10 < possibleDocIds.length) ? i + 10 : possibleDocIds.length;
          final batch = possibleDocIds.sublist(i, end);

          final querySnapshot = await FirebaseFirestore.instance
              .collection('$_clientPath/attendance')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          foundDocs.addAll(querySnapshot.docs);
        }
      }

      if (!_isMounted) return; // Check after all async operations

      if (foundDocs.isNotEmpty) {
        _processQueryResults(foundDocs);
      } else {
        // If still no records found, reset statistics
        _resetStatistics();
      }
    } catch (error) {
      print('Error in document ID fetch method: $error');
      // Reset statistics if both methods fail
      if (_isMounted) {
        _resetStatistics();
      }
    }
  }

  // Process query results from either fetch method
  void _processQueryResults(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (!_isMounted) return; // Check if still mounted
    
    attendanceRecords = docs.map((doc) {
      final data = doc.data();

      // Calculate if late
      final arrivalTime = data['arrival_time'] ?? '';
      final isLate = _timeSettings.isTimeLate(arrivalTime);

      // Check if departure_time exists and is not empty
      final departureTime = data['departure_time'] ?? '';
      final isActive = departureTime == '';

      // Check if early departure
      final isEarlyDeparture = _timeSettings.isEarlyDeparture(departureTime);

      // Add auto_completed field check
      final isAutoCompleted = data['auto_completed'] ?? false;

      // Get date either from field or document ID
      String dateStr = data['date'] ?? '';
      if (dateStr.isEmpty && doc.id.contains('_')) {
        dateStr = doc.id.split('_')[1];
      }

      return {
        'id': doc.id,
        'staffId': data['staff_id'] ?? widget.staffId,
        'arrivalTime': arrivalTime,
        'departureTime': departureTime,
        'date': dateStr,
        'isLate': isLate,
        'isActive': isActive,
        'isEarlyDeparture': isEarlyDeparture,
        'isAutoCompleted': isAutoCompleted,
        'timestamp': data['timestamp'] ?? '',
      };
    }).toList();
  }

  // Calculate statistics based on processed records
  void _calculateStatistics() {
    if (!_isMounted) return; // Early return if not mounted
    
    if (attendanceRecords.isEmpty) {
      _resetStatistics();
      return;
    }

    // Calculate statistics
    StaffInfoUtils.calculateStats(
      attendanceRecords: attendanceRecords,
      timeSettings: _timeSettings,
      startDate: startDate,
      endDate: endDate,
      onStatsCalculated: (stats) {
        if (_isMounted) { // Check if still mounted before updating state
          setState(() {
            totalAttendanceDays = stats.totalAttendanceDays;
            daysPresent = stats.daysPresent;
            daysLate = stats.daysLate;
            daysAbsent = stats.daysAbsent;
            averageArrivalTime = stats.averageArrivalTime;
            averageDepartureTime = stats.averageDepartureTime;
            averageHoursWorked = stats.averageHoursWorked;
            weeklyAttendanceData = stats.weeklyAttendanceData;
            // Add this line to save the daysEarlyArrival value
            daysEarlyArrival = stats.daysEarlyArrival;
          });
        }
      },
    );
  }

  // Reset all statistics values
  void _resetStatistics() {
    if (!_isMounted) return; // Early return if not mounted
    
    setState(() {
      totalAttendanceDays = 0;
      daysPresent = 0;
      daysLate = 0;
      daysAbsent = 0;
      averageArrivalTime = '--:--';
      averageDepartureTime = '--:--';
      averageHoursWorked = 0;
      weeklyAttendanceData = List.filled(7, 0);
      daysEarlyArrival = 0;
    });
  }

  void _changeDateRange(String range) async {
    if (!_isMounted) return; // Early return if not mounted
    
    final now = DateTime.now();
    DateTime newStartDate;
    DateTime newEndDate = now;
    String newRangeLabel = range;

    switch (range) {
      case 'Today':
        newStartDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        // Start from Monday of current week
        final daysFromMonday = now.weekday - 1;
        newStartDate = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));
        break;
      case 'This Month':
        // Start from 1st of current month
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
        // Show date range picker
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

        if (!_isMounted) return; // Check mount status after async operation

        if (pickedRange != null) {
          newStartDate = pickedRange.start;
          newEndDate = pickedRange.end;
          newRangeLabel =
              '${DateFormat('MMM d').format(newStartDate)} - ${DateFormat('MMM d, yyyy').format(newEndDate)}';
        } else {
          // User canceled the picker, keep current dates
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
                      // Updated Date Range Selector
                      DateRangeSelector(
                        employeeStartDate: employeeStartDate,
                        currentStartDate: startDate,
                        currentEndDate: endDate,
                        currentDateRange: currentDateRange,
                        onRangeSelected: _changeDateRange,
                      ),

                      const SizedBox(height: 16),

                      // Staff profile card
                      StaffInfoWidgets.buildProfileCard(
                        context,
                        widget.staffName,
                        widget.profileImageUrl,
                      ),

                      const SizedBox(height: 16),

                      // Summary statistics
                      StaffInfoWidgets.buildSummaryStats(
                        daysEarlyArrival: daysEarlyArrival,
                        daysLate: daysLate,
                        daysAbsent: daysAbsent,
                      ),

                      const SizedBox(height: 20),

                      StaffInfoWidgets.buildAttendanceBreakdownChart(
                        daysEarlyArrival: daysEarlyArrival,
                        daysLate: daysLate,
                        daysAbsent: daysAbsent,
                      ),

                    
                      const SizedBox(height: 20),

                      // Tabbed section for attendance history and statistics
                      StaffInfoWidgets.buildAttendanceTabs(
                        context,
                        _tabController,
                        attendanceRecords: attendanceRecords,
                        totalAttendanceDays: totalAttendanceDays,
                        daysPresent: daysPresent,
                        daysLate: daysLate,
                        daysAbsent: daysAbsent,
                        averageHoursWorked: averageHoursWorked,
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
            // Skeleton for date range selector
            Container(
              margin: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              height: 45,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            // Skeleton for profile card
            Container(
              margin: const EdgeInsets.all(16),
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 16),

            // Skeleton for summary stats
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 16),

            // Skeleton for average times
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 16),

            // Skeleton for chart
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 16),

            // Skeleton for tab view
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