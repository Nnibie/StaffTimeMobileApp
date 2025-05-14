import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_time/Widgets/AttendanceTile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/app_theme.dart';
import 'package:staff_time/Screens/SettingsScreen.dart';
import 'package:staff_time/Screens/RecordsScreen.dart';
import 'package:staff_time/Screens/StaffScreen.dart';
import 'package:staff_time/Widgets/utility/time_settings.dart'; // Import TimeSettings utility
import 'package:shimmer/shimmer.dart'; // Add shimmer package for skeleton loading
import 'dart:async';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Early', 'Late', 'Absent'];
  
  // Navigation index
  int _currentIndex = 0;
  
  // Store attendance data
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> staffData = [];
  bool isLoading = true;
  
  // Attendance metrics
  int presentCount = 0;
  int lateCount = 0;
  int absentCount = 0;
  int totalStaff = 0;
  
  // Stream subscriptions for realtime updates
  StreamSubscription<QuerySnapshot>? _attendanceSubscription;
  StreamSubscription<QuerySnapshot>? _staffSubscription;
  
  // Firestore path constants for new structure
  final String _clientId = 'PWA';
  final String _clientPath = 'Clients/PWA';
  
  // Time settings instance
  final TimeSettings _timeSettings = TimeSettings();
  
  @override
  void initState() {
    super.initState();
    _initializeTimeSettings();
  }
  
  // Initialize time settings before setting up listeners
  Future<void> _initializeTimeSettings() async {
    await _timeSettings.init();
    setupRealtimeListeners();
  }
  
  @override
  void dispose() {
    // Cancel subscriptions when widget is disposed
    _attendanceSubscription?.cancel();
    _staffSubscription?.cancel();
    super.dispose();
  }
  
  void setupRealtimeListeners() {
    setState(() {
      isLoading = true;
    });
    
    // Get today's date in string format YYYY-MM-DD
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    // Set up realtime listener for staff collection (previously teachers)
    _staffSubscription = FirebaseFirestore.instance
      .collection('$_clientPath/staff')
      .snapshots()
      .listen((snapshot) {
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
        
        // After staff data is loaded, update attendance metrics
        _updateAttendanceMetrics();
        
        setState(() {});
      }, onError: (error) {
        print('Error getting staff: $error');
        setState(() {
          isLoading = false;
        });
      });
    
    // Set up realtime listener for today's attendance - from new path
    _attendanceSubscription = FirebaseFirestore.instance
        .collection('$_clientPath/attendance')
        .where('date', isEqualTo: today)
        .snapshots()
        .listen((snapshot) {
          final List<String> presentStaffIds = [];
          
          attendanceRecords = snapshot.docs
              .map((doc) {
                final data = doc.data();
                
                // Get staffId from staff_id
                final staffId = data['staff_id'];
                presentStaffIds.add(staffId);
                
                // Check if staff is late (using time settings)
                final arrivalTime = data['arrival_time'];
                final isLate = _timeSettings.isTimeLate(arrivalTime);
                
                // Check if departure_time exists and is not empty
                final departureTime = data['departure_time'] ?? '';
                final isActive = departureTime == ''; // Staff is active if there's no departure time
                
                return {
                  'id': doc.id,
                  'staffId': staffId,
                  'arrivalTime': arrivalTime,
                  'departureTime': departureTime,
                  'staffName': data['staff_name'],
                  'date': data['date'],
                  'isLate': isLate,
                  'isActive': isActive, // Employee is active if there's no departure time
                  'isEarlyDeparture': _timeSettings.isEarlyDeparture(departureTime),
                };
              })
              .toList();
          
          // Update attendance metrics
          _updateAttendanceMetrics();
          
          setState(() {
            isLoading = false;
          });
        }, onError: (error) {
          print('Error getting attendance: $error');
          setState(() {
            isLoading = false;
          });
        });
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

  // Handler to navigate between screens
  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Method to get the appropriate screen based on nav index
  Widget _getScreenForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const RecordsScreen();
      case 2:
        return const StaffScreen();
      default:
        return _buildDashboardContent();
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
          _currentIndex == 0 ? 'Prudent Way Academy' : 
          _currentIndex == 1 ? 'Records' : 'Staff',
          style: AppTheme.headerMediumStyle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            color: AppTheme.primaryColor,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                // Refresh time settings when returning from settings screen
                _timeSettings.init().then((_) {
                  // Reload attendance data with updated time settings
                  _attendanceSubscription?.cancel();
                  setupRealtimeListeners();
                });
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _getScreenForIndex(_currentIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.secondaryTextColor,
        backgroundColor: Colors.white,
        elevation: 8,
        iconSize: 24,
        selectedLabelStyle: AppTheme.bodySmallStyle.copyWith(
          fontWeight: FontWeight.w600, 
          color: AppTheme.primaryColor
        ),
        unselectedLabelStyle: AppTheme.bodySmallStyle,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Staff',
          ),
        ],
      ),
    );
  }

  // Main dashboard content extracted from original code
  Widget _buildDashboardContent() {
    // Get current date
    final now = DateTime.now();
    final dateFormat = DateFormat('E, d\'${_getDaySuffix(now.day)}\' MMMM');
    final formattedDate = dateFormat.format(now);

    return RefreshIndicator(
      onRefresh: () async {
        // Manual refresh - reinitialize time settings and reload data
        await _timeSettings.init();
        await Future.delayed(const Duration(milliseconds: 300));
        _attendanceSubscription?.cancel();
        setupRealtimeListeners();
      },
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: AppTheme.dateStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Good ${_getGreeting()}, Admin',
                    style: AppTheme.headerLargeStyle,
                  ),
                ],
              ),
            ),
            
            // Attendance Summary Cards - with skeleton loading when needed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: AppTheme.cardDecoration,
                child: isLoading 
                  ? _buildSkeletonSummaryCards()
                  : Row(
                      children: [
                        _buildSummaryCard('Present', presentCount.toString(), 'out of $totalStaff', AppTheme.presentColor),
                        _buildDivider(),
                        _buildSummaryCard('Late', lateCount.toString(), 'employees', AppTheme.lateColor),
                        _buildDivider(),
                        _buildSummaryCard('Absent', absentCount.toString(), 'employees', AppTheme.absentColor),
                      ],
                    ),
              ),
            ),
            
            // Today's Attendance Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              child: Text(
                'Today\'s Attendance',
                style: AppTheme.headerMediumStyle,
              ),
            ),
            
            // Filter Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) => _buildFilterButton(filter)).toList(),
                ),
              ),
            ),
            
            // Attendance Tiles - with skeleton loading when needed
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isLoading 
                ? _buildSkeletonAttendanceTiles()
                : Column(
                    children: _buildAttendanceTiles(),
                  ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Skeleton loading for summary cards
  Widget _buildSkeletonSummaryCards() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: [
          _buildSkeletonSummaryCard(),
          _buildDivider(),
          _buildSkeletonSummaryCard(),
          _buildDivider(),
          _buildSkeletonSummaryCard(),
        ],
      ),
    );
  }
  
  // Skeleton for individual summary card
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
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Container(
              width: 30,
              height: 24,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            Container(
              width: 70,
              height: 12,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
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

  // Get greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
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

  Widget _buildSummaryCard(String title, String count, String subtitle, Color countColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: AppTheme.statsLabelStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              count,
              style: AppTheme.statsNumberStyle.copyWith(color: countColor),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: AppTheme.statsSubtitleStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppTheme.dividerColor,
    );
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
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
            'No ${_selectedFilter.toLowerCase()} staff today',
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
        department: 'Staff',  // Changed from 'Teacher' to 'Staff'
        initials: initials,
        photoUrl: staffRecord['profileImageUrl'],
        clockInTime: arrivalTimeFormatted,
        isClockInLate: record['isLate'],
        clockOutTime: departureTimeFormatted,
        isActive: record['isActive'],
        isClockOutEarly: !record['isActive'] && record['isEarlyDeparture'],
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
          department: 'Staff',  // Changed from 'Teacher' to 'Staff'
          initials: initials,
          photoUrl: staff['profileImageUrl'],
          clockInTime: 'Absent',
          isClockInLate: false,
          clockOutTime: '--:--',
          isClockOutEarly: false,
          totalHours: '',
        );
      }).toList();
      
      return absentTiles.isEmpty
          ? [
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Text(
                  'No absent staff today',
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