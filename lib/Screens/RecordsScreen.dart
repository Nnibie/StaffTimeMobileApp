import 'package:flutter/material.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/Widgets/AttendanceTile.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _selectedDay =
      DateTime.now().subtract(const Duration(days: 1)); // Default to yesterday
  String _selectedFilter = 'All';
  bool _isLoading = true;

  // Store attendance data
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> staffData = [];

  // Time settings instance
  final TimeSettings _timeSettings = TimeSettings();

  // Attendance metrics
  int presentCount = 0;
  int lateCount = 0;
  int absentCount = 0;
  int totalStaff = 0;

  // Keys for shared preferences
  static const String _selectedFilterKey = 'selectedFilter';
  Set<DateTime> _selectableDates = {};

  

  @override
  bool get wantKeepAlive => true; // Keep this widget alive when navigating away

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  // Load saved filter and date preferences
  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load saved filter (optional)
    final savedFilter = prefs.getString(_selectedFilterKey);
    if (savedFilter != null) {
      if (mounted) {
        setState(() {
          _selectedFilter = savedFilter;
        });
      }
    }
    
    // Fetch the list of all dates that are valid for selection
    await _fetchAndCacheSelectableDates();
    
    // Initialize time settings and load data for the default date (yesterday)
    await _initializeTimeSettings();
  }
  // Find the oldest available date in the attendance collection
  

  // Save current preferences
 Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Only save the filter, not the date.
    await prefs.setString(_selectedFilterKey, _selectedFilter);
  }

  // Initialize time settings before loading data
  Future<void> _initializeTimeSettings() async {
    await _timeSettings.init();
    _loadDataForSelectedDate();
  }

  // Get today's date with time set to 00:00:00
  DateTime _getTodayWithoutTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // Date selection dialog
  Future<void> _showDatePicker() async {
    // Safety Check 1: If there are no historical records at all, inform the user.
    if (_selectableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No historical attendance records found.")),
      );
      return;
    }

    // --- Start of New, Safer Date Calculation ---

    // 1. Determine the absolute boundaries from our data.
    final DateTime firstAvailableDate = _selectableDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final DateTime lastAvailableDate = _selectableDates.reduce((a, b) => a.isAfter(b) ? a : b);
    
    // 2. The last date for the picker cannot be in the future. It's either the last date
    //    we have data for, or yesterday, whichever is earlier.
    final DateTime yesterday = _getTodayWithoutTime().subtract(const Duration(days: 1));
    final DateTime finalLastDate = lastAvailableDate.isAfter(yesterday) ? yesterday : lastAvailableDate;

    // Safety Check 2: This is the critical fix for the crash.
    // If, after all calculations, the final last date is still before the first available date,
    // it means all our data is for "today" or the future, so there are no valid historical
    // records to show in this screen.
    if (finalLastDate.isBefore(firstAvailableDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No historical records are available to view.")),
      );
      return;
    }
    
    // --- End of New, Safer Date Calculation ---

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      // The initial date should also be clamped within the valid range.
      initialDate: _selectedDay.isAfter(finalLastDate) 
                   ? finalLastDate 
                   : _selectedDay.isBefore(firstAvailableDate) 
                     ? firstAvailableDate
                     : _selectedDay,
      firstDate: firstAvailableDate, // Use the safe, calculated first date
      lastDate: finalLastDate,     // Use the safe, calculated last date
      
      selectableDayPredicate: (DateTime day) {
        return _selectableDates.contains(DateTime(day.year, day.month, day.day));
      },
      
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.primaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null && pickedDate != _selectedDay) {
      setState(() {
        _selectedDay = pickedDate;
      });
      _savePreferences(); 
      _loadDataForSelectedDate();
    }
  }


  // Load data for the selected date
  Future<void> _loadDataForSelectedDate() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadStaffData(),
      _loadAttendanceData(),
    ]);

    _updateAttendanceMetrics();

    setState(() {
      _isLoading = false;
    });
  }

  // Load staff data from Firestore
  Future<void> _loadStaffData() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Clients/PWA/users') // Correct collection
          .where('role', isEqualTo: 'staff') // Filter for staff
          .get();

      staffData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'uuid': data['uuid'],
          'firstName': data['firstName'],
          'lastName': data['lastName'],
          'profileImageUrl': data['profileImageUrl'],
        };
      }).toList();

      totalStaff = staffData.length;
    } catch (error) {
      print('Error getting staff data: $error');
    }
  }

  // Load attendance data for selected date
  Future<void> _loadAttendanceData() async {
    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Clients/PWA/attendance_test') // Correct collection
          .where('date', isEqualTo: selectedDateStr)
          .where('role', isEqualTo: 'staff') // Filter for staff
          .get();

      attendanceRecords = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Handle nullable Timestamps
        final Timestamp? clockInTimestamp = data['clockIn'];
        final Timestamp? clockOutTimestamp = data['clockOut'];

        final DateTime? clockInTime = clockInTimestamp?.toDate();
        final DateTime? clockOutTime = clockOutTimestamp?.toDate();

        final isLate = clockInTime != null
            ? _timeSettings.isTimeLate(DateFormat('HH:mm').format(clockInTime))
            : false;
        final isEarlyDeparture = clockOutTime != null
            ? _timeSettings
                .isEarlyDeparture(DateFormat('HH:mm').format(clockOutTime))
            : false;
        final isActive = clockOutTime == null && clockInTime != null;
        final isAutoCompleted = data['auto_completed'] ?? false;

        return {
          'id': doc.id,
          'staffId': data['userId'],
          'staffName': data['userName'],
          'clockIn': clockInTime,
          'clockOut': clockOutTime,
          'isLate': isLate,
          'isActive': isActive,
          'isEarlyDeparture': isEarlyDeparture,
          'isAutoCompleted': isAutoCompleted,
        };
      }).toList();
    } catch (error) {
      print('Error getting attendance data: $error');
    }
  }

  void _updateAttendanceMetrics() {
    // Count present staff (those with attendance records)
    final presentStaffIds =
        attendanceRecords.map((record) => record['staffId'] as String).toSet();
    presentCount = presentStaffIds.length;

    // Count late staff
    lateCount =
        attendanceRecords.where((record) => record['isLate'] == true).length;

    // Count absent staff (staff without attendance records)
    absentCount = totalStaff - presentCount;
  }

  // Calculate total hours worked
  String _calculateTotalHours(DateTime? clockIn, DateTime? clockOut) {
    if (clockIn == null || clockOut == null) return '';

    try {
      final difference = clockOut.difference(clockIn);
      if (difference.isNegative) return 'Error';

      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;

      return '${hours}h ${minutes}m';
    } catch (e) {
      return '';
    }
  }

  // Format time from 24h to 12h format
  String _formatDateTimeToAmPm(DateTime? dt) {
    // CORRECT NAME
    if (dt == null) return '--:--';
    return DateFormat('h:mm a').format(dt);
  }

  // Get a user-friendly date display text
  String _getDateDisplayText() {
    final today = _getTodayWithoutTime();
    final yesterday = today.subtract(const Duration(days: 1));

    if (_selectedDay.year == yesterday.year &&
        _selectedDay.month == yesterday.month &&
        _selectedDay.day == yesterday.day) {
      return 'Yesterday';
    } else {
      final dateFormat =
          DateFormat('E, d\'${_getDaySuffix(_selectedDay.day)}\' MMMM yyyy');
      return dateFormat.format(_selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Get formatted date display
    final dateDisplayText = _getDateDisplayText();

    return Container(
      color: AppTheme.backgroundColor,
      child: RefreshIndicator(
       onRefresh: () async {
          // When refreshing, first re-fetch the list of valid dates.
          await _fetchAndCacheSelectableDates();
          // Then, reload the data for the currently selected day.
          await _loadDataForSelectedDate();
        },
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date selector
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                child: GestureDetector(
                  onTap: _showDatePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromRGBO(0, 0, 0, 0.05),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateDisplayText,
                          style: AppTheme.headerSmallStyle,
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Filter Buttons - Updated to match Dashboard style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterButton('All'),
                      _buildFilterButtonWithCount(
                          'Early',
                          presentCount -
                              lateCount), // More efficient calculation
                      _buildFilterButtonWithCount('Late', lateCount),
                      _buildFilterButtonWithCount('Absent', absentCount),
                    ],
                  ),
                ),
              ),

              // Attendance Tiles - with skeleton loading when needed
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isLoading
                    ? _buildSkeletonAttendanceTiles()
                    : Column(
                        children: _buildAttendanceTiles(),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Updated filter button without count (for "All")
  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
        _savePreferences();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: AppTheme.getFilterButtonDecoration(isSelected, filter),
        child: Text(
          filter,
          style: AppTheme.filterButtonStyle.copyWith(
            color: isSelected ? Colors.white : AppTheme.darkGrey,
          ),
        ),
      ),
    );
  }

  // Updated filter button with count indicator - MODIFIED TO USE DOT SEPARATOR
  Widget _buildFilterButtonWithCount(String filter, int count) {
    final isSelected = _selectedFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
        _savePreferences();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: AppTheme.getFilterButtonDecoration(isSelected, filter),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$filter • ${count.toString()}',
              style: AppTheme.filterButtonStyle.copyWith(
                color: isSelected ? Colors.white : AppTheme.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Get color for filter buttons
 

  // Skeleton loading for attendance tiles
  Widget _buildSkeletonAttendanceTiles() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(5, (index) => _buildSkeletonAttendanceTile()),
      ),
    );
  }

  // Skeleton for individual attendance tile
  Widget _buildSkeletonAttendanceTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
            ),

            const SizedBox(width: 12),

            // Info placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status badge placeholder
            Container(
              width: 60,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get day suffix (st, nd, rd, th)
  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  // Create the list of attendance tiles based on filter
  List<Widget> _buildAttendanceTiles() {
    List<Map<String, dynamic>> displayedRecords = [];

    // Determine which records to display based on the selected filter
    if (_selectedFilter == 'All') {
      displayedRecords = attendanceRecords;
    } else if (_selectedFilter == 'Late') {
      displayedRecords = attendanceRecords
          .where((record) => record['isLate'] == true)
          .toList();
    } else if (_selectedFilter == 'Early') {
      displayedRecords = attendanceRecords
          .where((record) =>
              record['isLate'] == false && record['clockIn'] != null)
          .toList();
    } else if (_selectedFilter == 'Absent') {
      // For 'Absent', we build tiles from the staff list, not the attendance list.
      final presentStaffIds = attendanceRecords
          .map((record) => record['staffId'] as String)
          .toSet();
      final absentStaffList = staffData
          .where((staff) => !presentStaffIds.contains(staff['uuid']))
          .toList();

      if (absentStaffList.isEmpty) {
        return [
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Text(
              'No absent staff on this date',
              style: AppTheme.bodyMediumStyle
                  .copyWith(color: AppTheme.secondaryTextColor),
            ),
          ),
        ];
      }

      return absentStaffList.map((staff) {
        final fullName = '${staff['firstName']} ${staff['lastName']}';
        final initials = (staff['firstName']?.isNotEmpty == true
                ? staff['firstName'][0]
                : '') +
            (staff['lastName']?.isNotEmpty == true ? staff['lastName'][0] : '');

        return AttendanceTile(
          name: fullName,
          department: 'Staff',
          initials: initials,
          photoUrl: staff['profileImageUrl'],
          clockInTime: 'Absent',
          isClockInLate: false,
          clockOutTime: '--:--',
          isClockOutEarly: false,
          isAutoCompleted: false,
          totalHours: '',
        );
      }).toList();
    }

    // If no records for "All", "Late", or "Early" filters, show a message.
    if (displayedRecords.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          child: Text(
            'No ${_selectedFilter.toLowerCase()} staff on this date',
            style: AppTheme.bodyMediumStyle
                .copyWith(color: AppTheme.secondaryTextColor),
          ),
        ),
      ];
    }

    // Build the tiles for present staff.
    return displayedRecords.map((record) {
      final staffInfo = staffData.firstWhere(
        (staff) => staff['uuid'] == record['staffId'],
        orElse: () => {}, // Return an empty map if staff not found
      );

      final fullName = record['staffName'] ?? 'Unknown Staff';
      final initials = (staffInfo['firstName']?.isNotEmpty == true
              ? staffInfo['firstName'][0]
              : '') +
          (staffInfo['lastName']?.isNotEmpty == true
              ? staffInfo['lastName'][0]
              : '');

      return AttendanceTile(
        name: fullName,
        department: 'Staff',
        initials: initials,
        photoUrl: staffInfo['profileImageUrl'],
        clockInTime: _formatDateTimeToAmPm(record['clockIn']),
        clockOutTime: _formatDateTimeToAmPm(record['clockOut']),
        isClockInLate: record['isLate'],
        isClockOutEarly: record['isEarlyDeparture'],
        isActive: record['isActive'],
        isAutoCompleted: record['isAutoCompleted'],
        totalHours: _calculateTotalHours(record['clockIn'], record['clockOut']),
      );
    }).toList();
  }
  Future<void> _fetchAndCacheSelectableDates() async {
    print("Fetching all valid attendance dates from Firestore...");
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Clients/PWA/attendance_test')
          .where('role', isEqualTo: 'staff')
          // We can't do a distinct query directly, so we fetch all dates
          // and process them on the client side. This is efficient enough
          // for thousands of records.
          .get();

      if (snapshot.docs.isEmpty) {
        print("No attendance records found at all.");
        return;
      }

      // Use a Set to automatically handle duplicates and get unique dates.
      final uniqueDateStrings = snapshot.docs.map((doc) => doc['date'] as String).toSet();
      
      // Convert the date strings to DateTime objects for the picker.
      final Set<DateTime> validDates = uniqueDateStrings
          .map((dateStr) => DateTime.parse(dateStr))
          .toSet();

      if (mounted) {
        setState(() {
          _selectableDates = validDates;
        });
      }
      print("Found ${_selectableDates.length} unique dates with records.");

    } catch (error) {
      print('Error fetching selectable dates: $error');
    }
  }
}
