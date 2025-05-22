import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:staff_time/Theme/app_theme.dart';

import 'staff_info.dart'; 

class StaffScreen extends StatefulWidget {
  const StaffScreen({Key? key}) : super(key: key);

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> staffList = [];
  bool isLoading = true;
  String searchQuery = '';
  
  // Firestore path constants
  final String _clientPath = 'Clients/PWA';
  
  @override
  void initState() {
    super.initState();
    loadStaffData();
  }
  
  Future<void> loadStaffData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Fetch staff data from Firestore
      final snapshot = await FirebaseFirestore.instance
        .collection('$_clientPath/staff')
        .get();
      
      setState(() {
        staffList = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'uuid': doc.id,
            'firstName': doc['firstName'] ?? '',
            'lastName': doc['lastName'] ?? '',
            'profileImageUrl': doc['profileImageUrl'] ?? '',
          };
        }).toList();
        
        // Sort staff alphabetically by first name
        staffList.sort((a, b) => 
          a['firstName'].toString().compareTo(b['firstName'].toString()));
        
        isLoading = false;
      });
    } catch (error) {
      print('Error loading staff data: $error');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Filter staff based on search query
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
    
    return Container(
      color: AppTheme.backgroundColor,
      child: RefreshIndicator(
        onRefresh: loadStaffData,
        color: AppTheme.primaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staff header with count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Row(
                children: [
                  Text(
                    'Staff Members',
                    style: AppTheme.headerMediumStyle,
                  ),
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
            
            // Search bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search staff...',
                  hintStyle: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
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
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            
            // Staff list
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
    final firstName = staff['firstName'];
    final lastName = staff['lastName'];
    final profileImageUrl = staff['profileImageUrl'];
    final staffId = staff['id'];
    final fullName = '$firstName $lastName';
    
    // Generate initials from name
    final initials = firstName.isNotEmpty && lastName.isNotEmpty
      ? '${firstName[0]}${lastName[0]}'
      : '';
    
    return InkWell(
      onTap: () {
        // Navigate to Staff Info screen when card is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffInfo(
              staffId: staffId,
              staffName: fullName,
              profileImageUrl: profileImageUrl,
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
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile image or initials
              profileImageUrl != null && profileImageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.network(
                      profileImageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildInitialsAvatar(initials);
                      },
                    ),
                  )
                : _buildInitialsAvatar(initials),
              
              const SizedBox(width: 16),
              
              // Staff details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: AppTheme.headerSmallStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff Member',
                      style: AppTheme.bodySmallStyle,
                    ),
                  ],
                ),
              ),
              
              // Info button
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                onPressed: () {
                  _showStaffDetails(staff);
                },
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
          initials,
          style: AppTheme.headerMediumStyle.copyWith(
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
  
  void _showStaffDetails(Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: staff['profileImageUrl'] != null && staff['profileImageUrl'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(
                        staff['profileImageUrl'],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${staff['firstName'][0]}${staff['lastName'][0]}',
                          style: AppTheme.headerLargeStyle.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${staff['firstName']} ${staff['lastName']}',
                  style: AppTheme.headerMediumStyle,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Staff Member',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Staff ID', staff['uuid']),
              const SizedBox(height: 32),
              Row(
                children: [
                  // View Details button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to Staff Info screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StaffInfo(
                              staffId: staff['id'],
                              staffName: '${staff['firstName']} ${staff['lastName']}',
                              profileImageUrl: staff['profileImageUrl'],
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'View Details',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Close button
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Close',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
          Text(
            label,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 12,
                      color: Colors.white,
                    ),
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
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.secondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty
              ? 'No staff members found'
              : 'No staff found with that name',
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          if (searchQuery.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                  });
                },
                child: const Text('Clear Search'),
              ),
            ),
        ],
      ),
    );
  }
}