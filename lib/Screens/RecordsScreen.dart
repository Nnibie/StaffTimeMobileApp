import 'package:flutter/material.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/Widgets/AttendanceTile.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({Key? key}) : super(key: key);

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> with AutomaticKeepAliveClientMixin {
  DateTime _selectedDay = DateTime.now().subtract(const Duration(days: 1)); // Default to yesterday
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
  
  // Firestore path constants
  final String _clientPath = 'Clients/PWA';
  
  // Keys for shared preferences
  static const String _selectedDateKey = 'selectedDate';
  static const String _selectedFilterKey = 'selectedFilter';
  
  // Track the oldest available date in the database
  DateTime? _oldestAvailableDate;
  
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
    
    // Load saved date (defaulting to yesterday if not set)
    final savedDateMillis = prefs.getInt(_selectedDateKey);
    if (savedDateMillis != null) {
      final savedDate = DateTime.fromMillisecondsSinceEpoch(savedDateMillis);
      // Only use saved date if it's not today or in the future
      if (savedDate.isBefore(_getTodayWithoutTime())) {
        setState(() {
          _selectedDay = savedDate;
        });
      }
    }
    
    // Load saved filter
    final savedFilter = prefs.getString(_selectedFilterKey);
    if (savedFilter != null) {
      setState(() {
        _selectedFilter = savedFilter;
      });
    }
    
    // Find the oldest available date in the database
    await _findOldestAvailableDate();
    
    // Initialize time settings and load data
    await _initializeTimeSettings();
  }
  
  // Find the oldest available date in the attendance collection
  Future<void> _findOldestAvailableDate() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('$_clientPath/attendance')
        .orderBy('date', descending: false) // Order by date ascending to get oldest first
        .limit(1) // Limit to just the first (oldest) document
        .get();
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        final dateStr = data['date'] as String;
        
        // Parse the date string (format YYYY-MM-DD)
        final dateParts = dateStr.split('-');
        if (dateParts.length == 3) {
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          
          setState(() {
            _oldestAvailableDate = DateTime(year, month, day);
          });
          
          print('Oldest available date found: $_oldestAvailableDate');
        }
      } else {
        print('No attendance records found to determine oldest date');
        // Set a reasonable fallback date if no records are found
        setState(() {
          _oldestAvailableDate = DateTime(2023, 1, 1); // Default to a reasonable past date
        });
      }
    } catch (error) {
      print('Error finding oldest date: $error');
      // Set a fallback date in case of error
      setState(() {
        _oldestAvailableDate = DateTime(2023, 1, 1);
      });
    }
  }
  
  // Save current preferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedDateKey, _selectedDay.millisecondsSinceEpoch);
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
    // Set maximum date to yesterday
    final DateTime yesterday = _getTodayWithoutTime().subtract(const Duration(days: 1));
    
    // Use oldest available date from database, or a reasonable fallback
    final DateTime firstDate = _oldestAvailableDate ?? DateTime(2020);
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: firstDate, // Use oldest available date from database
      lastDate: yesterday, // Can't select today or future dates
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
      await _savePreferences();
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
        .collection('$_clientPath/staff')
        .get();
      
      staffData = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'uuid': doc.id, 
          'firstName': doc['firstName'],
          'lastName': doc['lastName'],
          'profileImageUrl': doc['profileImageUrl'],
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
      // Format date as YYYY-MM-DD
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
      
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('$_clientPath/attendance')
        .where('date', isEqualTo: selectedDateStr)
        .get();
      
      attendanceRecords = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Get staff ID from staff_id
        final staffId = data['staff_id'];
        
        // Check if staff is late (using time settings)
        final arrivalTime = data['arrival_time'];
        final isLate = _timeSettings.isTimeLate(arrivalTime);
        
        // Check if departure_time exists and is not empty
        final departureTime = data['departure_time'] ?? '';
        final isActive = departureTime == ''; // Staff is active if there's no departure time
        
        // Add auto_completed field check
        final isAutoCompleted = data['auto_completed'] ?? false;
        
        return {
          'id': doc.id,
          'staffId': staffId,
          'arrivalTime': arrivalTime,
          'departureTime': departureTime,
          'staffName': data['staff_name'],
          'date': data['date'],
          'isLate': isLate,
          'isActive': isActive,
          'isEarlyDeparture': _timeSettings.isEarlyDeparture(departureTime),
          'isAutoCompleted': isAutoCompleted,
        };
      }).toList();
    } catch (error) {
      print('Error getting attendance data: $error');
    }
  }
  
  void _updateAttendanceMetrics() {
    // Count present staff (those with attendance records)
    final presentStaffIds = attendanceRecords.map((record) => record['staffId'] as String).toSet();
    presentCount = presentStaffIds.length;
    
    // Count late staff
    lateCount = attendanceRecords.where((record) => record['isLate'] == true).length;
    
    // Count absent staff (staff without attendance records)
    absentCount = totalStaff - presentCount;
  }
  
  // Calculate total hours worked
  String _calculateTotalHours(String arrivalTime, String departureTime) {
    // Return empty string if departure time is empty (still active)
    if (departureTime == '') return '';
    
    try {
      final arrival = _parseTimeString(arrivalTime);
      final departure = _parseTimeString(departureTime);
      
      final difference = departure.difference(arrival);
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      
      return '${hours}h ${minutes}m';
    } catch (e) {
      return '';
    }
  }
  
  // Parse time string (HH:MM) to DateTime
  DateTime _parseTimeString(String timeString) {
    final timeParts = timeString.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
  
  // Format time from 24h to 12h format
  String _formatTimeToAmPm(String time24h) {
    try {
      if (time24h == '') return '--:--';
      
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
  
  // Get a user-friendly date display text
  String _getDateDisplayText() {
    final today = _getTodayWithoutTime();
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (_selectedDay.year == yesterday.year && 
        _selectedDay.month == yesterday.month && 
        _selectedDay.day == yesterday.day) {
      return 'Yesterday';
    } else {
      final dateFormat = DateFormat('E, d\'${_getDaySuffix(_selectedDay.day)}\' MMMM yyyy');
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
          // Manual refresh - reinitialize time settings and reload data
          await _timeSettings.init();
          // Also refresh the oldest available date
          await _findOldestAvailableDate();
          await Future.delayed(const Duration(milliseconds: 300));
          _loadDataForSelectedDate();
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
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                      _buildFilterButtonWithCount('Early', attendanceRecords.where((record) => !record['isLate']).length),
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
    final color = _getFilterColor(filter);
    
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
    final color = _getFilterColor(filter);
    
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
  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'All':
        return AppTheme.primaryColor;
      case 'Early':
        return AppTheme.presentColor;
      case 'Late':
        return AppTheme.lateColor;
      case 'Absent':
        return AppTheme.absentColor;
      default:
        return AppTheme.primaryColor;
    }
  }
  
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
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // Create the list of attendance tiles based on filter
  List<Widget> _buildAttendanceTiles() {
    // Get filtered records
    List<Map<String, dynamic>> filteredRecords = [];
    List<String> absentStaffIds = [];
    
    // Find absent staff - only needed for 'Absent' filter
    if (_selectedFilter == 'Absent') {
      final presentStaffIds = attendanceRecords.map((record) => record['staffId'] as String).toSet();
      absentStaffIds = staffData
          .map((staff) => staff['uuid'] as String)
          .where((uuid) => !presentStaffIds.contains(uuid))
          .toList();
    }
    
    // Filter based on selection
    if (_selectedFilter == 'All') {
      filteredRecords = attendanceRecords;
    } else if (_selectedFilter == 'Late') {
      filteredRecords = attendanceRecords.where((record) => record['isLate'] == true).toList();
    } else if (_selectedFilter == 'Early') {
      filteredRecords = attendanceRecords.where((record) => record['isLate'] == false).toList();
    }
    
    // If no records after filtering, show message
    if (filteredRecords.isEmpty && (_selectedFilter != 'Absent' || absentStaffIds.isEmpty)) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          child: Text(
            'No ${_selectedFilter.toLowerCase()} staff on this date',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
      ];
    }
    
    // Create tiles for present staff
    final List<Widget> presentTiles = filteredRecords.map<Widget>((record) {
      // Find staff data to get profile image
      final staffId = record['staffId'];
      final staffRecord = staffData.firstWhere(
        (t) => t['uuid'] == staffId,
        orElse: () => {'profileImageUrl': null},
      );
      
      // Get staff name and prepare initials
      final staffName = record['staffName'];
      final nameParts = staffName.split(' ');
      String initials = '';
      if (nameParts.isNotEmpty) {
        initials = nameParts.map((part) => part.isNotEmpty ? part[0] : '').join('');
      }
      
      final arrivalTimeFormatted = _formatTimeToAmPm(record['arrivalTime']);
      
      // Format departure time based on active status
      final departureTimeFormatted = record['isActive'] ? 
          '--:--' : _formatTimeToAmPm(record['departureTime']);
      
      // Calculate total hours only for inactive employees
      final totalHours = record['isActive'] ? 
          '' : _calculateTotalHours(record['arrivalTime'], record['departureTime']);
      
      return AttendanceTile(
        name: staffName,
        department: 'Staff',
        initials: initials,
        photoUrl: staffRecord['profileImageUrl'],
        clockInTime: arrivalTimeFormatted,
        isClockInLate: record['isLate'],
        clockOutTime: departureTimeFormatted,
        isActive: record['isActive'],
        isClockOutEarly: !record['isActive'] && record['isEarlyDeparture'],
        isAutoCompleted: record['isAutoCompleted'],
        totalHours: totalHours,
      );
    }).toList();
    
    // Create tiles for absent staff - only for 'Absent' filter
    if (_selectedFilter == 'Absent') {
      final List<Widget> absentTiles = absentStaffIds.map<Widget>((uuid) {
        final staff = staffData.firstWhere(
          (t) => t['uuid'] == uuid,
          orElse: () => {'firstName': '', 'lastName': '', 'profileImageUrl': null},
        );
        
        final fullName = '${staff['firstName']} ${staff['lastName']}';
        final initials = staff['firstName'].isNotEmpty && staff['lastName'].isNotEmpty
            ? '${staff['firstName'][0]}${staff['lastName'][0]}'
            : '';
        
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
      
      return absentTiles.isEmpty
          ? [
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Text(
                  'No absent staff on this date',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ),
            ]
          : absentTiles;
    }
    
    // For All, Early, Late filters - just return the present tiles
    return presentTiles;
  }
}