import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_time/Widgets/AttendanceTile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'package:staff_time/Screens/SettingsScreen.dart';
import 'package:staff_time/Screens/RecordsScreen.dart';
import 'package:staff_time/Screens/StaffScreen.dart';
import 'package:staff_time/utility/time_settings.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Early', 'Late', 'Absent'];
  
  // Navigation index
  int _currentIndex = 0;

  late PageController _pageController;
  
  // Store attendance data
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> staffUserData = []; 
  bool isLoading = true;
  
  // Attendance metrics
  int presentCount = 0;
  int lateCount = 0;
  int absentCount = 0;
  int totalStaff = 0;
  
  // Stream subscriptions for realtime updates
  StreamSubscription<QuerySnapshot>? _attendanceSubscription;
   StreamSubscription<QuerySnapshot>? _userSubscription;
  
  // Firestore path constants for new structure
final String _clientId = 'PWA';
  
  // Time settings instance
  final TimeSettings _timeSettings = TimeSettings();
  
  // Animation controller for new arrivals
  late AnimationController _newArrivalController;
  late Animation<double> _newArrivalAnimation;
  
  // Track previous attendance records for detecting new arrivals
  List<String> _previousAttendanceIds = [];
  String? _latestArrivalId;
  
  @override
void initState() {
  super.initState();
  // Initialize PageController with current index
  _pageController = PageController(initialPage: _currentIndex);
  
  // Initialize animation controller for new arrivals
  _newArrivalController = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );
  
  _newArrivalAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _newArrivalController,
    curve: Curves.easeOutBack,
  ));
  
  _initializeTimeSettings();
}
  
  // Initialize time settings before setting up listeners
  Future<void> _initializeTimeSettings() async {
    await _timeSettings.init();
    setupRealtimeListeners();
  }

  void _onPageChanged(int index) {
  setState(() {
    _currentIndex = index;
  });
}
  
@override
void dispose() {
  // Cancel subscriptions when widget is disposed
  _attendanceSubscription?.cancel();
 _userSubscription?.cancel();
  
  // Dispose controllers
  _pageController.dispose();
  _newArrivalController.dispose();
  
  super.dispose();
}
  
 void setupRealtimeListeners() {
    setState(() {
      isLoading = true;
    });

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // --- LISTENER 1: FETCH USERS WITH "staff" ROLE ---
    // The path is now built dynamically using _clientId
    _userSubscription = FirebaseFirestore.instance
      .collection('Clients/$_clientId/users') // DYNAMIC PATH
      .where('role', isEqualTo: 'staff')
      .snapshots()
      .listen((snapshot) {
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
        if (mounted) setState(() {});

      }, onError: (error) {
        print('Error getting users for client $_clientId: $error'); // Enhanced logging
        if (mounted) setState(() => isLoading = false);
      });

    // --- LISTENER 2: FETCH TODAY'S ATTENDANCE FOR "staff" ROLE ---
    // The path is now built dynamically using _clientId
    _attendanceSubscription = FirebaseFirestore.instance
        .collection('Clients/$_clientId/attendance_test') // DYNAMIC PATH
        .where('date', isEqualTo: today)
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .listen((snapshot) {
          final newAttendanceRecords = snapshot.docs.map((doc) {
            final data = doc.data();
            
            final Timestamp? clockInTimestamp = data['clockIn'];
            final Timestamp? clockOutTimestamp = data['clockOut'];
            
            final DateTime? clockInTime = clockInTimestamp?.toDate();
            final DateTime? clockOutTime = clockOutTimestamp?.toDate();
            
            final isLate = clockInTime != null ? _timeSettings.isTimeLate(DateFormat('HH:mm').format(clockInTime)) : false;
            final isEarlyDeparture = clockOutTime != null ? _timeSettings.isEarlyDeparture(DateFormat('HH:mm').format(clockOutTime)) : false;
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
          
          newAttendanceRecords.sort((a, b) {
            final aTime = a['clockIn'] as DateTime?;
            final bTime = b['clockIn'] as DateTime?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          
          if (!isLoading) {
            final currentIds = newAttendanceRecords.map((record) => record['id'] as String).toList();
            final newIds = currentIds.where((id) => !_previousAttendanceIds.contains(id)).toList();
            if (newIds.isNotEmpty) {
              _latestArrivalId = newIds.first;
              _newArrivalController.reset();
              _newArrivalController.forward();
            }
            _previousAttendanceIds = currentIds;
          }
          
          attendanceRecords = newAttendanceRecords;
          _updateAttendanceMetrics();
          
          if (mounted) setState(() => isLoading = false);

        }, onError: (error) {
          print('Error getting attendance for client $_clientId: $error'); // Enhanced logging
          if (mounted) setState(() => isLoading = false);
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
  String _calculateTotalHours(DateTime? clockIn, DateTime? clockOut) {
    // If either time is missing, we cannot calculate the total duration.
    if (clockIn == null || clockOut == null) return '';

    try {
      final difference = clockOut.difference(clockIn);
      // Handle cases where clock-out might be before clock-in (data error)
      if (difference.isNegative) return 'Error';

      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      
      return '${hours}h ${minutes}m';
    } catch (e) {
      return ''; // Return empty if any other error occurs
    }
  }
  
 
  
 

  // Handler to navigate between screens with animation
void _onNavItemTapped(int index) {
  _pageController.animateToPage(
    index,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
  
  setState(() {
    _currentIndex = index;
  });
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
      child: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const ClampingScrollPhysics(),
        children: [
          _buildDashboardContent(),
          const RecordsScreen(),
          const StaffScreen(),
        ],
      ),
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

  // Main dashboard content
  Widget _buildDashboardContent() {
    // Get current date
    final now = DateTime.now();
    final dateFormat = DateFormat('E, d\'${_getDaySuffix(now.day)}\' MMMM');
    final formattedDate = dateFormat.format(now);

    return RefreshIndicator(
      onRefresh: () async {
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
            
            // Attendance Summary Cards
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
            
            // Attendance Tiles
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isLoading 
                ? _buildSkeletonAttendanceTiles()
                : _buildAttendanceTiles(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Build attendance tiles with proper animation
  Widget _buildAttendanceTiles() {
    final tiles = _getFilteredAttendanceTiles();
    
    if (tiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          'No ${_selectedFilter.toLowerCase()} staff today',
          style: AppTheme.bodyMediumStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
        ),
      );
    }
    
    return Column(
      children: tiles.asMap().entries.map((entry) {
       
        final tileData = entry.value;
        
        // Check if this is the latest arrival for animation
        final isLatestArrival = tileData['id'] == _latestArrivalId;
        
        Widget tile = _buildAttendanceTileWidget(tileData);
        
        // Apply animation only to the latest arrival
        if (isLatestArrival && _latestArrivalId != null) {
          tile = AnimatedBuilder(
            animation: _newArrivalAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -30 * (1 - _newArrivalAnimation.value)),
                child: Opacity(
                  opacity: _newArrivalAnimation.value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: tile,
          );
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: tile,
        );
      }).toList(),
    );
  }

  // Get filtered attendance data
  List<Map<String, dynamic>> _getFilteredAttendanceTiles() {
    // --- Filter 1: Handle 'Absent' Staff ---
    // This must be handled first as it uses a different data source.
    if (_selectedFilter == 'Absent') {
      // Get a unique set of IDs for all staff who have clocked in today.
      final presentStaffIds = attendanceRecords.map((record) => record['staffId'] as String).toSet();
      
      // Filter the main staff user list to find who is NOT in the present list.
      return staffUserData
          .where((staff) => !presentStaffIds.contains(staff['uuid']))
          .map((staff) {
            // Create a special map for the absent tile.
            return {
              'id': 'absent_${staff['uuid']}', // Create a unique ID for the key
              'staffId': staff['uuid'],
              'staffName': '${staff['firstName']} ${staff['lastName']}',
              'isAbsent': true, // The flag to identify this as an absent tile
              'profileImageUrl': staff['profileImageUrl'],
              'clockIn': null, // Add null fields for type consistency
              'clockOut': null,
            };
          })
          .toList();
    }
    
    // --- Filter 2: Handle Present Staff (All, Late, Early) ---
    // These filters operate on the 'attendanceRecords' list.
    List<Map<String, dynamic>> filteredRecords;

    if (_selectedFilter == 'All') {
      // Return all records without any filtering.
      filteredRecords = attendanceRecords;

    } else if (_selectedFilter == 'Late') {
      // Return only records where the 'isLate' flag is true.
      filteredRecords = attendanceRecords
          .where((record) => record['isLate'] == true)
          .toList();

    } else if (_selectedFilter == 'Early') {
      // "Early" is defined as not late.
      // We also ensure there's a clock-in time to exclude "forgot to clock in" cases.
      filteredRecords = attendanceRecords
          .where((record) => record['isLate'] == false && record['clockIn'] != null)
          .toList();

    } else {
      // Default case if the filter is somehow unrecognized.
      filteredRecords = attendanceRecords;
    }
    
    return filteredRecords;
  }


  // Build individual attendance tile widget
  Widget _buildAttendanceTileWidget(Map<String, dynamic> tileData) {
    if (tileData['isAbsent'] == true) {
      final staffName = tileData['staffName'];
      final nameParts = staffName.split(' ');
      final initials = nameParts.map((part) => part.isNotEmpty ? part[0] : '').join('');
      
      return AttendanceTile(
        name: staffName,
        department: 'Staff',
        initials: initials,
        photoUrl: tileData['profileImageUrl'],
        clockInTime: 'Absent',
        isClockInLate: false,
        clockOutTime: '--:--',
        totalHours: '',
      );
    } else {
      final staffId = tileData['staffId'];
      // CHANGED: Use staffUserData list now
      final staffRecord = staffUserData.firstWhere(
        (t) => t['uuid'] == staffId,
        orElse: () => {'profileImageUrl': null},
      );
      
      final staffName = tileData['staffName'];
      final nameParts = staffName.split(' ');
      final initials = nameParts.map((part) => part.isNotEmpty ? part[0] : '').join('');

      final arrivalTimeFormatted = _formatDateTimeToAmPm(tileData['clockIn']);
      final departureTimeFormatted = _formatDateTimeToAmPm(tileData['clockOut']);
      final totalHours = _calculateTotalHours(tileData['clockIn'], tileData['clockOut']);
      
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
      );
    }
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
}

String _formatDateTimeToAmPm(DateTime? dt) {
    // If the datetime is null (e.g., forgot to clock in/out), display '--:--'
    if (dt == null) return '--:--';
    
    // Use the intl package to format the time correctly
    return DateFormat('h:mm a').format(dt);
  }