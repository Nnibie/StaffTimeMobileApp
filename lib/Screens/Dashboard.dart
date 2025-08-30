// lib/screens/dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_time/Widgets/AttendanceTile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:staff_time/screens/recordsscreen.dart';
import 'package:staff_time/screens/staffscreen.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'settings_screen.dart';
import 'dart:developer';

// This is the correct service import for your AdminUser class
import 'package:staff_time/services/admin_auth_service.dart';
import 'staff_info.dart'; // FIX: Import the StaffInfo screen

// This is the correct StatefulWidget definition from your new code
class DashboardScreen extends StatefulWidget {
  final AdminUser loggedInAdmin;

  const DashboardScreen({super.key, required this.loggedInAdmin});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // --- STATE FOR THE CLIENT SWITCHER (from new code) ---
  String? _selectedClientId;
  String _selectedClientName = "Loading Client...";
  final Map<String, String> _clientDetails = {};

  // --- All your original state variables ---
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'On Time',
    'Late',
    'Absent'
  ]; // FIX: Changed 'Early' to 'On Time' for honesty
  int _currentIndex = 0;
  late PageController _pageController;
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> staffUserData = [];
  bool isLoading = true;
  int presentCount = 0;
  int lateCount = 0;
  int absentCount = 0;
  int totalStaff = 0;
  StreamSubscription<QuerySnapshot>? _attendanceSubscription;
  StreamSubscription<QuerySnapshot>? _userSubscription;
  final TimeSettings _timeSettings = TimeSettings();
  late AnimationController _newArrivalController;
  late Animation<double> _newArrivalAnimation;
  List<String> _previousAttendanceIds = [];
  String? _latestArrivalId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _newArrivalController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _newArrivalAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _newArrivalController, curve: Curves.easeOutBack));

    // This is the correct starting point from your new code
    _initializeClientData();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    _userSubscription?.cancel();
    _pageController.dispose();
    _newArrivalController.dispose();
    super.dispose();
  }

  // This entire block of logic for handling clients is from your new code and is correct.
  Future<void> _initializeClientData() async {
    final clientIds = widget.loggedInAdmin.clientIds;
    if (clientIds.isEmpty) {
      if (mounted) {
        setState(() {
          _selectedClientName = "No Clients Assigned";
          isLoading = false;
        });
      }
      return;
    }

    for (String id in clientIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('Clients')
            .doc(id)
            .get();
        if (doc.exists) {
          _clientDetails[id] = doc.data()?['name'] ?? 'Unknown Client';
        }
      } catch (e) {
        log("Could not fetch name for client $id: $e");
      }
    }

    if (mounted) {
      _selectClient(clientIds.first);
    }
  }

  void _selectClient(String clientId) {
    if (mounted) {
      setState(() {
        _selectedClientId = clientId;
        _selectedClientName = _clientDetails[clientId] ?? '...';
        isLoading = true;
        attendanceRecords = [];
        staffUserData = [];
      });
    }

    _attendanceSubscription?.cancel();
    _userSubscription?.cancel();
    _initializeTimeSettings();
  }

  Future<void> _initializeTimeSettings() async {
    await _timeSettings.init(_selectedClientId ?? '');
    setupRealtimeListeners();
  }

  void setupRealtimeListeners() {
    if (_selectedClientId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    _userSubscription = FirebaseFirestore.instance
        .collection('Clients/$_selectedClientId/users')
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      staffUserData = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'uuid': data['uuid'],
          'firstName': data['firstName'],
          'lastName': data['lastName'],
          'profileImageUrl': data['profileImageUrl'],
        };
      }).toList();
      totalStaff = staffUserData.length;
      _updateAttendanceMetrics();
      setState(() {});
    }, onError: (error) {
      log('Error getting users for client $_selectedClientId: $error');
      if (mounted) setState(() => isLoading = false);
    });

    _attendanceSubscription = FirebaseFirestore.instance
        .collection('Clients/$_selectedClientId/attendance_test')
        .where('date', isEqualTo: today)
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final newAttendanceRecords = snapshot.docs.map((doc) {
        final data = doc.data();
        final clockInTime = (data['clockIn'] as Timestamp?)?.toDate();
        final clockOutTime = (data['clockOut'] as Timestamp?)?.toDate();
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
      newAttendanceRecords.sort((a, b) =>
          (b['clockIn'] as DateTime? ?? DateTime(0))
              .compareTo(a['clockIn'] as DateTime? ?? DateTime(0)));

      if (!isLoading) {
        final currentIds =
            newAttendanceRecords.map((r) => r['id'] as String).toList();
        final newIds = currentIds
            .where((id) => !_previousAttendanceIds.contains(id))
            .toList();
        if (newIds.isNotEmpty) {
          _latestArrivalId = newIds.first;
          _newArrivalController.reset();
          _newArrivalController.forward();
        }
        _previousAttendanceIds = currentIds;
      } else {
        _previousAttendanceIds =
            newAttendanceRecords.map((r) => r['id'] as String).toList();
      }

      attendanceRecords = newAttendanceRecords;
      _updateAttendanceMetrics();
      setState(() => isLoading = false);
    }, onError: (error) {
      log('Error getting attendance for client $_selectedClientId: $error');
      if (mounted) setState(() => isLoading = false);
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onNavItemTapped(int index) {
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentIndex = index);
  }

  void _showClientSwitcher() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: _clientDetails.entries.map((entry) {
            final isSelected = entry.key == _selectedClientId;
            return ListTile(
              title: Text(entry.value,
                  style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal)),
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.business,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
              onTap: () {
                Navigator.of(context).pop();
                if (!isSelected) {
                  _selectClient(entry.key);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          _currentIndex == 0
              ? _selectedClientName
              : _currentIndex == 1
                  ? 'Records'
                  : 'Staff',
          style: AppTheme.headerMediumStyle,
        ),
        centerTitle: true,
        actions: [
          if (_clientDetails.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              color: AppTheme.primaryColor,
              onPressed: _showClientSwitcher,
              tooltip: 'Switch Client',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            color: AppTheme.primaryColor,
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                // The fix is on this line: we pass the required data
                MaterialPageRoute(
                    builder: (context) =>
                        SettingsScreen(loggedInAdmin: widget.loggedInAdmin)),
              ).then((_) {
                // This ".then" block remains the same, ensuring settings are reloaded
                _timeSettings.init(_selectedClientId ?? '').then((_) {
                  if (_selectedClientId != null) {
                    _selectClient(_selectedClientId!);
                  }
                });
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: [
            _buildDashboardContent(),
            RecordsScreen(clientId: _selectedClientId ?? ''),
            StaffScreen(clientId: _selectedClientId ?? ''),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.secondaryTextColor,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Records'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Staff'),
        ],
      ),
    );
  }

  void _updateAttendanceMetrics() {
    final presentStaffIds =
        attendanceRecords.map((record) => record['staffId'] as String).toSet();
    presentCount = presentStaffIds.length;
    lateCount =
        attendanceRecords.where((record) => record['isLate'] == true).length;
    absentCount = totalStaff - presentCount;
  }

  String _calculateTotalHours(DateTime? clockIn, DateTime? clockOut) {
    if (clockIn == null || clockOut == null) return '';
    final difference = clockOut.difference(clockIn);
    if (difference.isNegative) return 'Error';
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Widget _buildDashboardContent() {
    final now = DateTime.now();
    final dateFormat = DateFormat('E, d\'${_getDaySuffix(now.day)}\' MMMM');
    final formattedDate = dateFormat.format(now);

    return RefreshIndicator(
      onRefresh: () async {
        await _timeSettings.init(_selectedClientId ?? '');
        if (_selectedClientId != null) {
          _selectClient(_selectedClientId!);
        }
      },
      color: AppTheme.primaryColor,
      child: isLoading
          ? _buildDashboardSkeleton() // FIX: Use the new, accurate skeleton
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formattedDate, style: AppTheme.dateStyle),
                        const SizedBox(height: 4),
                        Text(
                            'Good ${_getGreeting()}, ${widget.loggedInAdmin.firstName}',
                            style: AppTheme.headerLargeStyle),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: AppTheme.cardDecoration,
                      child: Row(
                        children: [
                          _buildSummaryCard('Present', presentCount.toString(),
                              'out of $totalStaff', AppTheme.presentColor),
                          _buildDivider(),
                          _buildSummaryCard('Late', lateCount.toString(),
                              'employees', AppTheme.lateColor),
                          _buildDivider(),
                          _buildSummaryCard('Absent', absentCount.toString(),
                              'employees', AppTheme.absentColor),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                    child: Text('Today\'s Attendance',
                        style: AppTheme.headerMediumStyle),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          children: _filters
                              .map((filter) => _buildFilterButton(filter))
                              .toList()),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAttendanceTiles(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildAttendanceTiles() {
    final tiles = _getFilteredAttendanceTiles();
    if (tiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text('No ${_selectedFilter.toLowerCase()} staff today',
            style: AppTheme.bodyMediumStyle
                .copyWith(color: AppTheme.secondaryTextColor)),
      );
    }
    return Column(
      children: tiles.asMap().entries.map((entry) {
        final tileData = entry.value;
        final isLatestArrival = tileData['id'] == _latestArrivalId;
        Widget tile = _buildAttendanceTileWidget(tileData);
        if (isLatestArrival && _latestArrivalId != null) {
          tile = AnimatedBuilder(
            animation: _newArrivalAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -30 * (1 - _newArrivalAnimation.value)),
              child: Opacity(
                  opacity: _newArrivalAnimation.value.clamp(0.0, 1.0),
                  child: child),
            ),
            child: tile,
          );
        }
        return Container(
            margin: const EdgeInsets.only(bottom: 10), child: tile);
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _getFilteredAttendanceTiles() {
    if (_selectedFilter == 'Absent') {
      final presentStaffIds = attendanceRecords
          .map((record) => record['staffId'] as String)
          .toSet();
      return staffUserData
          .where((staff) => !presentStaffIds.contains(staff['uuid']))
          .map((staff) => {
                'id': 'absent_${staff['uuid']}',
                'staffId': staff['uuid'],
                'staffDocumentId': staff['id'],
                'staffName': '${staff['firstName']} ${staff['lastName']}',
                'isAbsent': true,
                'profileImageUrl': staff['profileImageUrl'],
                'clockIn': null,
                'clockOut': null,
              })
          .toList();
    }
    List<Map<String, dynamic>> filteredRecords;
    if (_selectedFilter == 'Late') {
      filteredRecords = attendanceRecords
          .where((record) => record['isLate'] == true)
          .toList();
    } else if (_selectedFilter == 'On Time') {
      filteredRecords = attendanceRecords
          .where((record) =>
              record['isLate'] == false && record['clockIn'] != null)
          .toList();
    } else {
      filteredRecords = List.from(attendanceRecords);
    }
    return filteredRecords;
  }

  Widget _buildAttendanceTileWidget(Map<String, dynamic> tileData) {
    void navigateToStaffInfo(
        String staffDocumentId, String staffName, String? profileImageUrl) {
      if (_selectedClientId == null || staffDocumentId.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StaffInfo(
            staffId: staffDocumentId,
            staffName: staffName,
            profileImageUrl: profileImageUrl ?? '',
            clientId: _selectedClientId!,
          ),
        ),
      );
    }

    if (tileData['isAbsent'] == true) {
      final staffName = tileData['staffName'];
      final nameParts = staffName.split(' ');
      final initials =
          nameParts.map((part) => part.isNotEmpty ? part[0] : '').join('');
      return AttendanceTile(
          name: staffName,
          department: 'Staff',
          initials: initials,
          photoUrl: tileData['profileImageUrl'],
          clockInTime: 'Absent',
          isClockInLate: false,
          clockOutTime: '--:--',
          totalHours: '',
          onTap: () {
            navigateToStaffInfo(tileData['staffDocumentId'],
                tileData['staffName'], tileData['profileImageUrl']);
          });
    } else {
      final staffId = tileData['staffId'];
      final staffRecord = staffUserData.firstWhere((t) => t['uuid'] == staffId,
          orElse: () => {'profileImageUrl': null, 'id': ''});
      final staffName = tileData['staffName'];
      final nameParts = staffName.split(' ');
      final initials =
          nameParts.map((part) => part.isNotEmpty ? part[0] : '').join('');
      final arrivalTimeFormatted = _formatDateTimeToAmPm(tileData['clockIn']);
      final departureTimeFormatted =
          _formatDateTimeToAmPm(tileData['clockOut']);
      final totalHours =
          _calculateTotalHours(tileData['clockIn'], tileData['clockOut']);
      return AttendanceTile(
          name: staffName,
          department: 'Staff',
          initials: initials,
          photoUrl: staffRecord['profileImageUrl'],
          clockInTime: arrivalTimeFormatted,
          isClockInLate: tileData['isLate'],
          clockOutTime: departureTimeFormatted,
          isActive: tileData['isActive'],
          isClockOutEarly: tileData['isEarlyDeparture'],
          isAutoCompleted: tileData['isAutoCompleted'],
          totalHours: totalHours,
          onTap: () {
            navigateToStaffInfo(
                staffRecord['id'], staffName, staffRecord['profileImageUrl']);
          });
    }
  }

  // --- SKELETON UI ---

  // FIX: This is the new, primary skeleton widget. It perfectly mirrors the real UI structure.
  Widget _buildDashboardSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics:
            const NeverScrollableScrollPhysics(), // Disable scroll on skeleton
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Placeholder for Greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 16,
                      width: 220,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 8),
                  Container(
                      height: 28,
                      width: 180,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8))),
                ],
              ),
            ),
            // 2. Placeholder for Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: AppTheme.cardDecoration,
                child: Row(
                  children: [
                    _buildSkeletonSummaryCard(),
                    _buildDivider(),
                    _buildSkeletonSummaryCard(),
                    _buildDivider(),
                    _buildSkeletonSummaryCard(),
                  ],
                ),
              ),
            ),
            // 3. Placeholder for "Today's Attendance" title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              child: Container(
                  height: 22,
                  width: 200,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8))),
            ),
            // 4. Placeholder for Filter Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                        width: 70,
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18))),
                    const SizedBox(width: 10),
                    Container(
                        width: 90,
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18))),
                    const SizedBox(width: 10),
                    Container(
                        width: 80,
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18))),
                    const SizedBox(width: 10),
                    Container(
                        width: 95,
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            // 5. Placeholder for Attendance List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children:
                    List.generate(5, (_) => _buildSkeletonAttendanceTile()),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonSummaryCard() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 60,
                height: 14,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(
                width: 30,
                height: 24,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Container(
                width: 70,
                height: 12,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonAttendanceTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 25, backgroundColor: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 140,
                    height: 18,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                        width: 70,
                        height: 12,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 16),
                    Container(
                        width: 70,
                        height: 12,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ],
            ),
          ),
          Container(
              width: 60,
              height: 26,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15))),
        ],
      ),
    );
  }

  // --- HELPER METHODS ---

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
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

  Widget _buildSummaryCard(
      String title, String count, String subtitle, Color countColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: AppTheme.statsLabelStyle, textAlign: TextAlign.center),
            const SizedBox(height: 5),
            Text(count,
                style: AppTheme.statsNumberStyle.copyWith(color: countColor),
                textAlign: TextAlign.center),
            Text(subtitle,
                style: AppTheme.statsSubtitleStyle,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: AppTheme.dividerColor);
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: AppTheme.getFilterButtonDecoration(isSelected, filter),
        child: Text(filter,
            style: AppTheme.filterButtonStyle.copyWith(
                color: isSelected ? Colors.white : AppTheme.darkGrey)),
      ),
    );
  }
}

String _formatDateTimeToAmPm(DateTime? dt) {
  if (dt == null) return '--:--';
  return DateFormat('h:mm a').format(dt);
}
