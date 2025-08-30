// lib/screens/staffscreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:staff_time/Theme/app_theme.dart';
import 'dart:async';
import 'dart:developer'; // Using developer log for better debugging
import 'staff_info.dart';


class StaffScreen extends StatefulWidget {
  // FIX: This property allows the widget to accept a client ID
  final String clientId;

  // FIX: The constructor now requires the clientId to be passed in
  const StaffScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}


class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> staffList = [];
  bool isLoading = true;
  String searchQuery = '';

  StreamSubscription<QuerySnapshot>? _staffSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupStaffStream();
  }
  
  @override
  void dispose() {
    _staffSubscription?.cancel();
    super.dispose();
  }

  
   @override
  void didUpdateWidget(covariant StaffScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientId != oldWidget.clientId) {
      log("Client ID changed in StaffScreen. Reloading staff list for ${widget.clientId}");
      _setupStaffStream();
    }
  }

   void _setupStaffStream() {
    // Cancel any existing stream to prevent multiple listeners
    _staffSubscription?.cancel();

    // FIX: Safety check to prevent loading if no client is selected
    if (widget.clientId.isEmpty) {
      setState(() {
        isLoading = false;
        staffList = [];
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    // FIX: Using dynamic widget.clientId instead of a hardcoded value
    final query = FirebaseFirestore.instance
        .collection('Clients/${widget.clientId}/users')
        .where('role', isEqualTo: 'staff');

    _staffSubscription = query.snapshots().listen((snapshot) {
      if (!mounted) return;

      setState(() {
        staffList = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'uuid': data['uuid'] ?? doc.id,
            'firstName': data['firstName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'profileImageUrl': data['profileImageUrl'] ?? '',
          };
        }).toList();
        
        staffList.sort((a, b) => a['firstName'].toString().compareTo(b['firstName'].toString()));
        isLoading = false;
      });

    }, onError: (error) {
      log('Error listening to staff stream for client ${widget.clientId}: $error');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    });
  }
  
  List<Map<String, dynamic>> getFilteredStaff() {
    if (searchQuery.isEmpty) {
      return staffList;
    }
    return staffList.where((staff) {
      final fullName = '${staff['firstName']} ${staff['lastName']}'.toLowerCase();
      return fullName.contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = getFilteredStaff();
    
    // FIX: Show a clear message if no client is selected
    if (widget.clientId.isEmpty) {
      return  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
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
        onRefresh:() async {
          // Re-run the setup to ensure we have the latest data.
          _setupStaffStream();
          await Future.delayed(const Duration(seconds: 1));
        },
        color: AppTheme.primaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Row(
                children: [
                   Text('Staff Members', style: AppTheme.headerMediumStyle),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${filteredStaff.length}',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search staff...',
                  hintStyle: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            
            Expanded(
              child: isLoading
                ? _buildLoadingShimmer()
                : filteredStaff.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredStaff.length,
                      itemBuilder: (context, index) {
                        final staff = filteredStaff[index];
                        return _buildStaffCard(staff);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final firstName = staff['firstName'] ?? '';
    final lastName = staff['lastName'] ?? '';
    final profileImageUrl = staff['profileImageUrl'] ?? '';
    final staffId = staff['id'] ?? '';
    final fullName = '$firstName $lastName';
    final initials = firstName.isNotEmpty && lastName.isNotEmpty ? '${firstName[0]}${lastName[0]}' : '';
    
    return InkWell(
      onTap: () {
        // FIX: Pass the current client ID to the details screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffInfo(
              staffId: staffId,
              staffName: fullName,
              profileImageUrl: profileImageUrl,
              clientId: widget.clientId, // Pass the client ID
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              profileImageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(
                      profileImageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildInitialsAvatar(initials),
                    ),
                  )
                : _buildInitialsAvatar(initials),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: AppTheme.headerSmallStyle),
                    const SizedBox(height: 4),
                     Text('Staff Member', style: AppTheme.bodySmallStyle),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                onPressed: () => _showStaffDetails(staff),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInitialsAvatar(String initials) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: AppTheme.headerMediumStyle.copyWith(color: AppTheme.primaryColor),
        ),
      ),
    );
  }
  
   void _showStaffDetails(Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Center(
                child: (staff['profileImageUrl'] != null && staff['profileImageUrl'].isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(staff['profileImageUrl'], width: 100, height: 100, fit: BoxFit.cover),
                    )
                  : _buildInitialsAvatar('${staff['firstName'][0]}${staff['lastName'][0]}'),
              ),
              const SizedBox(height: 24),
              Center(child: Text('${staff['firstName']} ${staff['lastName']}', style: AppTheme.headerMediumStyle)),
              const SizedBox(height: 8),
              Center(child: Text('Staff Member', style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor))),
              const SizedBox(height: 24),
              _buildDetailRow('Staff ID', staff['uuid']),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // FIX: Ensure client ID is passed on this navigation too
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StaffInfo(
                              staffId: staff['id'],
                              staffName: '${staff['firstName']} ${staff['lastName']}',
                              profileImageUrl: staff['profileImageUrl'],
                              clientId: widget.clientId,
                            ),
                          ),
                        );
                      },
                      child: Text('View Details', style: AppTheme.bodyMediumStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.primaryColor)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor)),
          Text(value, style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 12, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppTheme.secondaryTextColor),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? 'No staff members found' : 'No staff found for "$searchQuery"',
            style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}