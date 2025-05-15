import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceTile extends StatelessWidget {
  final String name;
  final String department;
  final String? photoUrl;
  final String initials;
  final String clockInTime;
  final String clockOutTime;
  final String totalHours;
  final bool isClockInLate;
  final bool isClockOutEarly;
  final bool isClockOutLate;
  final bool isActive;
  final bool isAutoCompleted; // Add this line

  const AttendanceTile({
    Key? key,
    required this.name,
    required this.department,
    this.photoUrl,
    required this.initials,
    required this.clockInTime,
    required this.isClockInLate,
    required this.clockOutTime,
    this.isClockOutEarly = false,
    this.isClockOutLate = false,
    this.isActive = false,
    this.isAutoCompleted = false, // Add this line with default value
    required this.totalHours,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEEEEEE),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with photo
            photoUrl != null && photoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(
                      photoUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(width: 50), // Empty space if no photo (no fallback)
            
            const SizedBox(width: 12),
            
            // Employee info and time details
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Employee info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        Text(
                          department,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Clock in/out info
                        Row(
                          children: [
                            _buildTimeRow(
                              label: 'In:',
                              time: clockInTime,
                              isLate: isClockInLate,
                              isEarly: false,
                              isAuto: false, // Clock-in is never auto-completed
                            ),
                            const SizedBox(width: 16),
                            _buildTimeRow(
                              label: 'Out:',
                              time: clockOutTime,
                              isLate: isClockOutLate,
                              isEarly: isClockOutEarly,
                              isAuto: isAutoCompleted, // Pass the auto-completed flag here
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Status badge for active employees or Total hours
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FAF0),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2CA01C),
                        ),
                      ),
                    )
                  else if (totalHours.isNotEmpty)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'TOTAL',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        Text(
                          totalHours,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2CA01C),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow({
    required String label,
    required String time,
    required bool isLate,
    required bool isEarly,
    required bool isAuto, // Changed from default value to required
  }) {
    Color timeColor = const Color(0xFF2CA01C); // Default green for on-time
    
    if (time == '--:--') {
      timeColor = const Color(0xFF666666); // Gray for not clocked yet
    } else if (isAuto) {
      timeColor = const Color(0xFFFF9900); // Orange for auto-completed
    } else if (isLate) {
      timeColor = const Color(0xFFE74C3C); // Red for late
    } else if (isEarly) {
      timeColor = const Color(0xFFFF9900); // Orange for early departure
    }

    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF666666),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: timeColor,
          ),
        ),
        // Optional: Add a small indicator icon for auto-completed
        if (isAuto) 
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.access_time,
              size: 12,
              color: const Color(0xFFFF9900),
            ),
          ),
      ],
    );
  }
}