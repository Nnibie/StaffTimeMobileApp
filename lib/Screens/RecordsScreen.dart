// lib/screens/recordsscreen.dart

import 'package:flutter/material.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/Widgets/AttendanceTile.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer'; // Using developer log for better debugging
import 'staff_info.dart'; // FIX: Import the StaffInfo screen for navigation

class RecordsScreen extends StatefulWidget {
  // FIX: This property allows the widget to accept a client ID
  final String clientId;

  // FIX: The constructor now requires the clientId to be passed in
  const RecordsScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}


class _RecordsScreenState extends State<RecordsScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _selectedDay = DateTime.now().subtract(const Duration(days: 1));
  String _selectedFilter = 'All';
  bool _isLoading = true;

  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> staffData = [];
  final TimeSettings _timeSettings = TimeSettings();

  int presentCount = 0;
  int lateCount = 0;
  int absentCount = 0;
  int totalStaff = 0;

  static const String _selectedFilterKey = 'selectedFilter';
  Set<DateTime> _selectableDates = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Start loading preferences and data as soon as the widget is created.
    _loadSavedPreferences();
  }

   @override
  void didUpdateWidget(covariant RecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientId != oldWidget.clientId) {
      log("Client ID changed from ${oldWidget.clientId} to ${widget.clientId}. Reloading data.");
      // The client has been switched on the dashboard, reload everything.
      _loadDataForSelectedDate();
      _fetchAndCacheSelectableDates();
    }
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilter = prefs.getString(_selectedFilterKey);
    if (savedFilter != null && mounted) {
      setState(() {
        _selectedFilter = savedFilter;
      });
    }

    await _fetchAndCacheSelectableDates();
    await _initializeTimeSettings();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFilterKey, _selectedFilter);
  }

  Future<void> _initializeTimeSettings() async {
    await _timeSettings.init(widget.clientId);
    _loadDataForSelectedDate();
  }

  DateTime _getTodayWithoutTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _showDatePicker() async {
    if (_selectableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No historical attendance records found.")),
      );
      return;
    }

    final DateTime firstAvailableDate = _selectableDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final DateTime lastAvailableDate = _selectableDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final DateTime yesterday = _getTodayWithoutTime().subtract(const Duration(days: 1));
    final DateTime finalLastDate = lastAvailableDate.isAfter(yesterday) ? yesterday : lastAvailableDate;

    if (finalLastDate.isBefore(firstAvailableDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No historical records are available to view.")),
      );
      return;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isAfter(finalLastDate) 
                   ? finalLastDate 
                   : _selectedDay.isBefore(firstAvailableDate) 
                     ? firstAvailableDate
                     : _selectedDay,
      firstDate: firstAvailableDate,
      lastDate: finalLastDate,
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

  
  Future<void> _loadDataForSelectedDate() async {
    // FIX: Safety check to prevent loading if no client is selected.
    if (widget.clientId.isEmpty) {
      setState(() {
        _isLoading = false;
        staffData = [];
        attendanceRecords = [];
      });
      _updateAttendanceMetrics(); // This will correctly set counts to 0
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Load both staff and attendance data in parallel for efficiency
    await Future.wait([
      _loadStaffData(),
      _loadAttendanceData(),
    ]);

    _updateAttendanceMetrics();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _loadStaffData() async {
    if (widget.clientId.isEmpty) return; // Guard clause
    try {
      // FIX: Using dynamic widget.clientId instead of a hardcoded value
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Clients/${widget.clientId}/users')
          .where('role', isEqualTo: 'staff')
          .get();

      if (!mounted) return;
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
      log('Error getting staff data for client ${widget.clientId}: $error');
    }
  }

  Future<void> _loadAttendanceData() async {
    if (widget.clientId.isEmpty) return; // Guard clause
    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
      // FIX: Using dynamic widget.clientId instead of a hardcoded value
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Clients/${widget.clientId}/attendance_test')
          .where('date', isEqualTo: selectedDateStr)
          .where('role', isEqualTo: 'staff')
          .get();

      if (!mounted) return;
      attendanceRecords = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final clockInTime = (data['clockIn'] as Timestamp?)?.toDate();
        final clockOutTime = (data['clockOut'] as Timestamp?)?.toDate();
        return {
          'id': doc.id,
          'staffId': data['userId'],
          'staffName': data['userName'],
          'clockIn': clockInTime,
          'clockOut': clockOutTime,
          'isLate': clockInTime != null ? _timeSettings.isTimeLate(DateFormat('HH:mm').format(clockInTime)) : false,
          'isActive': clockOutTime == null && clockInTime != null,
          'isEarlyDeparture': clockOutTime != null ? _timeSettings.isEarlyDeparture(DateFormat('HH:mm').format(clockOutTime)) : false,
          'isAutoCompleted': data['auto_completed'] ?? false,
        };
      }).toList();
    } catch (error) {
      log('Error getting attendance data for client ${widget.clientId}: $error');
    }
  }

  Future<void> _fetchAndCacheSelectableDates() async {
    if (widget.clientId.isEmpty) {
      if (mounted) setState(() => _selectableDates = {});
      return;
    }
    log("Fetching all valid attendance dates for client: ${widget.clientId}...");
    try {
      // FIX: Using dynamic widget.clientId instead of a hardcoded value
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Clients/${widget.clientId}/attendance_test')
          .where('role', isEqualTo: 'staff')
          .get();

      if (snapshot.docs.isEmpty) {
        log("No attendance records found for client ${widget.clientId}.");
        if (mounted) setState(() => _selectableDates = {});
        return;
      }

      final uniqueDateStrings = snapshot.docs.map((doc) => doc['date'] as String).toSet();
      final Set<DateTime> validDates = uniqueDateStrings.map((dateStr) => DateTime.parse(dateStr)).toSet();

      if (mounted) {
        setState(() {
          _selectableDates = validDates;
        });
      }
      log("Found ${_selectableDates.length} unique dates with records for client ${widget.clientId}.");

    } catch (error) {
      log('Error fetching selectable dates: $error');
    }
  }

  void _updateAttendanceMetrics() {
    final presentStaffIds = attendanceRecords.map((record) => record['staffId'] as String).toSet();
    presentCount = presentStaffIds.length;
    lateCount = attendanceRecords.where((record) => record['isLate'] == true).length;
    absentCount = totalStaff - presentCount;
  }

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

  String _formatDateTimeToAmPm(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat('h:mm a').format(dt);
  }

  String _getDateDisplayText() {
    final today = _getTodayWithoutTime();
    final yesterday = today.subtract(const Duration(days: 1));
    if (_selectedDay.year == yesterday.year && _selectedDay.month == yesterday.month && _selectedDay.day == yesterday.day) {
      return 'Yesterday';
    } else {
      final dateFormat = DateFormat('E, d\'${_getDaySuffix(_selectedDay.day)}\' MMMM yyyy');
      return dateFormat.format(_selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // FIX: Show a clear message if no client is selected
    if (widget.clientId.isEmpty) {
      return  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Client Selected',
              style: AppTheme.headerMediumStyle,
            ),
            Text(
              'Please select a client from the Dashboard.',
              style: AppTheme.bodyMediumStyle,
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppTheme.backgroundColor,
      child: RefreshIndicator(
        onRefresh: () async {
          await _fetchAndCacheSelectableDates();
          await _loadDataForSelectedDate();
        },
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(_getDateDisplayText(), style: AppTheme.headerSmallStyle),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterButton('All'),
                      _buildFilterButtonWithCount('Early', presentCount - lateCount),
                      _buildFilterButtonWithCount('Late', lateCount),
                      _buildFilterButtonWithCount('Absent', absentCount),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isLoading ? _buildSkeletonAttendanceTiles() : Column(children: _buildAttendanceTiles()),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
        _savePreferences();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: AppTheme.getFilterButtonDecoration(isSelected, filter),
        child: Text(
          filter,
          style: AppTheme.filterButtonStyle.copyWith(color: isSelected ? Colors.white : AppTheme.darkGrey),
        ),
      ),
    );
  }

  Widget _buildFilterButtonWithCount(String filter, int count) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
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
              style: AppTheme.filterButtonStyle.copyWith(color: isSelected ? Colors.white : AppTheme.darkGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonAttendanceTiles() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(5, (index) => _buildSkeletonAttendanceTile()),
      ),
    );
  }

  Widget _buildSkeletonAttendanceTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 18, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 80, height: 14, color: Colors.white),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(width: 60, height: 12, color: Colors.white),
                      const SizedBox(width: 16),
                      Container(width: 60, height: 12, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
            Container(width: 60, height: 26, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
          ],
        ),
      ),
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  List<Widget> _buildAttendanceTiles() {
    List<Map<String, dynamic>> displayedRecords;

    // --- FIX: Navigation Logic ---
    void navigateToStaffInfo(String staffDocumentId, String staffName, String? profileImageUrl) {
        if (widget.clientId.isEmpty || staffDocumentId.isEmpty) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => StaffInfo(
                    staffId: staffDocumentId,
                    staffName: staffName,
                    profileImageUrl: profileImageUrl ?? '',
                    clientId: widget.clientId,
                ),
            ),
        );
    }

    if (_selectedFilter == 'All' || _selectedFilter == 'Late' || _selectedFilter == 'Early') {
      if (_selectedFilter == 'All') {
          displayedRecords = attendanceRecords;
      } else if (_selectedFilter == 'Late') {
          displayedRecords = attendanceRecords.where((record) => record['isLate'] == true).toList();
      } else { // Early
          displayedRecords = attendanceRecords.where((record) => record['isLate'] == false && record['clockIn'] != null).toList();
      }

      if (displayedRecords.isEmpty) {
          return [
              Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Text('No ${_selectedFilter.toLowerCase()} staff on this date', style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor)),
              ),
          ];
      }

      return displayedRecords.map((record) {
          final staffInfo = staffData.firstWhere((staff) => staff['uuid'] == record['staffId'], orElse: () => {});
          final fullName = record['staffName'] ?? 'Unknown Staff';
          final initials = (staffInfo['firstName']?.isNotEmpty == true ? staffInfo['firstName'][0] : '') +
              (staffInfo['lastName']?.isNotEmpty == true ? staffInfo['lastName'][0] : '');
          
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: AttendanceTile(
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
              onTap: () { // FIX: Added onTap for present/late/early staff
                  if (staffInfo.isNotEmpty) {
                    navigateToStaffInfo(staffInfo['id'], fullName, staffInfo['profileImageUrl']);
                  }
              },
            ),
          );
      }).toList();

    } else if (_selectedFilter == 'Absent') {
        final presentStaffIds = attendanceRecords.map((record) => record['staffId'] as String).toSet();
        final absentStaffList = staffData.where((staff) => !presentStaffIds.contains(staff['uuid'])).toList();

        if (absentStaffList.isEmpty) {
            return [
                Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: Text('No absent staff on this date', style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor)),
                ),
            ];
        }

        return absentStaffList.map((staff) {
            final fullName = '${staff['firstName']} ${staff['lastName']}';
            final initials = (staff['firstName']?.isNotEmpty == true ? staff['firstName'][0] : '') +
                (staff['lastName']?.isNotEmpty == true ? staff['lastName'][0] : '');
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: AttendanceTile(
                name: fullName,
                department: 'Staff',
                initials: initials,
                photoUrl: staff['profileImageUrl'],
                clockInTime: 'Absent',
                isClockInLate: false,
                clockOutTime: '--:--',
                totalHours: '',
                onTap: () { // FIX: Added onTap for absent staff
                  navigateToStaffInfo(staff['id'], fullName, staff['profileImageUrl']);
                },
              ),
            );
        }).toList();
    } else {
        return []; // Should not happen
    }
  }
}