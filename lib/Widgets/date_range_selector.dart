import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staff_time/Theme/app_theme.dart';

class DateRangeSelector extends StatelessWidget {
  final DateTime? employeeStartDate;
  final DateTime currentStartDate;
  final DateTime currentEndDate;
  final String currentDateRange;
  final Function(String) onRangeSelected;

  const DateRangeSelector({
    Key? key,
    required this.employeeStartDate,
    required this.currentStartDate,
    required this.currentEndDate,
    required this.currentDateRange,
    required this.onRangeSelected,
  }) : super(key: key);

  // Get a user-friendly date display text
  String _getDateDisplayText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // If custom date range is selected
    if (currentDateRange.contains('-')) {
      return currentDateRange;
    }
    
    // If it's a standard preset
    switch (currentDateRange) {
      case 'Today':
        return 'Today';
      case 'Yesterday':
      case 'Last Day':
        return 'Yesterday';
      case 'This Week':
        return 'This Week';
      case 'This Month':
        return 'This Month';
      case 'Last 30 Days':
        return 'Last 30 Days';
      default:
        // For "All Time" or other custom ranges
        return currentDateRange;
    }
  }

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
  
  // Check if an option should be enabled based on employee start date
  bool _isOptionEnabled(String option) {
    if (employeeStartDate == null) {
      return true; // If start date is unknown, enable all options
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (option) {
      case 'Today':
        // Only enable if the employee started today or earlier
        return !employeeStartDate!.isAfter(today);
        
      case 'Yesterday':
        // Only enable if the employee started yesterday or earlier
        final yesterday = today.subtract(const Duration(days: 1));
        return !employeeStartDate!.isAfter(yesterday);
        
      case 'This Week':
        // Only enable if the employee started this week or earlier
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return !employeeStartDate!.isAfter(startOfWeek);
        
      case 'This Month':
        // Only enable if the employee started this month or earlier
        final startOfMonth = DateTime(now.year, now.month, 1);
        return !employeeStartDate!.isAfter(startOfMonth);
        
      case 'Last 30 Days':
        // Only enable if the employee started at least 1 day within the last 30 days
        final thirtyDaysAgo = today.subtract(const Duration(days: 30));
        return !employeeStartDate!.isAfter(today) && 
               !employeeStartDate!.isBefore(thirtyDaysAgo.subtract(const Duration(days: 1)));
      
      case 'All Time':
        return true; // Always available
        
      case 'Custom':
        return true; // Always available
        
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateDisplayText = _getDateDisplayText();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: GestureDetector(
        onTap: () => _showDateRangeOptions(context),
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
    );
  }

  void _showDateRangeOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text(
                  'Select Date Range',
                  style: AppTheme.headerMediumStyle,
                ),
              ),
              _buildOptionTile(context, 'Today'),
              _buildOptionTile(context, 'This Week'),
              _buildOptionTile(context, 'This Month'),
              _buildOptionTile(context, 'All Time'),
              _buildOptionTile(context, 'Custom'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(BuildContext context, String option) {
    final isSelected = currentDateRange == option || 
      (currentDateRange.contains(option) && option == 'All Time');
    
    final bool isEnabled = _isOptionEnabled(option);
    
    return ListTile(
      enabled: isEnabled,
      leading: Icon(
        _getIconForOption(option),
        color: isSelected 
            ? AppTheme.primaryColor 
            : (isEnabled ? Colors.grey : Colors.grey.withOpacity(0.5)),
      ),
      title: Text(
        option,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected 
              ? AppTheme.primaryColor 
              : (isEnabled ? AppTheme.primaryTextColor : Colors.grey.withOpacity(0.5)),
        ),
      ),
      trailing: isSelected 
        ? Icon(Icons.check_circle, color: AppTheme.primaryColor) 
        : null,
      onTap: isEnabled ? () {
        Navigator.pop(context);
        onRangeSelected(option);
      } : null,
    );
  }

  IconData _getIconForOption(String option) {
    switch (option) {
      case 'Today':
        return Icons.today;
      case 'This Week':
        return Icons.view_week;
      case 'This Month':
        return Icons.calendar_view_month;
      case 'Last 30 Days':
        return Icons.date_range;
      case 'All Time':
        return Icons.all_inclusive;
      case 'Custom':
        return Icons.calendar_month;
      default:
        return Icons.calendar_today;
    }
  }
}