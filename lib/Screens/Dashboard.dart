import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:staff_time/Widgets/AttendanceTile.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Early', 'Late', 'Absent'];

  @override
  Widget build(BuildContext context) {
    // Get current date
    final now = DateTime.now();
    final dateFormat = DateFormat('E, d\'${_getDaySuffix(now.day)}\' MMMM');
    final formattedDate = dateFormat.format(now);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with school name
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Prudent Way Academy',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2CA01C),
                  ),
                ),
              ),
              
              // Date and greeting
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Good morning, Georgina',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Attendance Summary Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildSummaryCard('Present', '30', 'out of 40', const Color(0xFF2CA01C)),
                      _buildDivider(),
                      _buildSummaryCard('Late', '4', 'employees', const Color(0xFFE74C3C)),
                      _buildDivider(),
                      _buildSummaryCard('Absent', '0', 'employees', Colors.grey[600]!),
                    ],
                  ),
                ),
              ),
              
              // Today's Attendance Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                child: Text(
                  'Today\'s Attendance',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
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
                child: Column(
                  children: [
              
                    // Display filtered attendance tiles
                    ..._buildAttendanceTiles(),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildSummaryCard(String title, String count, String subtitle, Color countColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              count,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: countColor,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.grey[600],
              ),
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
      color: Colors.grey[300],
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
        decoration: BoxDecoration(
          color: isSelected ? 
            filter == 'Early' ? const Color(0xFF2CA01C) :
            filter == 'Late' ? const Color(0xFFE74C3C) :
            filter == 'Absent' ? Colors.grey[800] :
            Colors.grey[800] // 'All' filter
            : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.grey[300]!,
          ),
        ),
        child: Text(
          filter,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[800],
          ),
        ),
      ),
    );
  }

  // Create the list of attendance tiles based on filter
  List<Widget> _buildAttendanceTiles() {
    // Filter attendance tiles based on selection
    if (_selectedFilter == 'All') {
      return [
        AttendanceTile(
          name: 'John Smith',
          department: 'Math Teacher',
          initials: 'JS',
          clockInTime: '8:30 AM',
          isClockInLate: false,
          clockOutTime: '5:15 PM',
          isClockOutLate: false,
          totalHours: '8h 45m',
        ),
        AttendanceTile(
          name: 'Amy Taylor',
          department: 'English Teacher',
          initials: 'AT',
          clockInTime: '8:50 AM',
          isClockInLate: false,
          clockOutTime: '4:30 PM',
          isClockOutEarly: true,
          totalHours: '7h 40m',
        ),
        AttendanceTile(
          name: 'Sarah Johnson',
          department: 'Science Teacher',
          initials: 'SJ',
          clockInTime: '8:45 AM',
          isClockInLate: false,
          clockOutTime: '--:--',
          isActive: true,
          totalHours: '',
        ),
        AttendanceTile(
          name: 'David Miller',
          department: 'PE Teacher',
          initials: 'DM',
          clockInTime: '9:15 AM',
          isClockInLate: true,
          clockOutTime: '--:--',
          isActive: true,
          totalHours: '',
        ),
      ];
    } else if (_selectedFilter == 'Late') {
      return [
        AttendanceTile(
          name: 'David Miller',
          department: 'PE Teacher',
          initials: 'DM',
          clockInTime: '9:15 AM',
          isClockInLate: true,
          clockOutTime: '--:--',
          isActive: true,
          totalHours: '',
        ),
        AttendanceTile(
          name: 'Mike Rodriguez',
          department: 'Art Teacher',
          initials: 'MR',
          clockInTime: '9:30 AM',
          isClockInLate: true,
          clockOutTime: '5:00 PM',
          totalHours: '7h 30m',
        ),
      ];
    } else if (_selectedFilter == 'Early') {
      return [
        AttendanceTile(
          name: 'John Smith',
          department: 'Math Teacher',
          initials: 'JS',
          clockInTime: '8:30 AM',
          isClockInLate: false,
          clockOutTime: '5:15 PM',
          isClockOutLate: false,
          totalHours: '8h 45m',
        ),
        AttendanceTile(
          name: 'Amy Taylor',
          department: 'English Teacher',
          initials: 'AT',
          clockInTime: '8:50 AM',
          isClockInLate: false,
          clockOutTime: '4:30 PM',
          isClockOutEarly: true,
          totalHours: '7h 40m',
        ),
        AttendanceTile(
          name: 'Sarah Johnson',
          department: 'Science Teacher',
          initials: 'SJ',
          clockInTime: '8:45 AM',
          isClockInLate: false,
          clockOutTime: '--:--',
          isActive: true,
          totalHours: '',
        ),
      ];
    } else if (_selectedFilter == 'Absent') {
      return [
        // No absent staff today
        Container(
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          child: Text(
            'No absent staff today',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
      ];
    }
    
    return [];
  }
}