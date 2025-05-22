import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme file for the Prudent Way Academy Staff Time app
/// Contains all colors, text styles, and other styling elements 
/// to maintain consistent design across the application.

class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation
  
  // Main Colors
  static const Color primaryColor = Color(0xFF2CA01C);      // Primary Green
  static const Color errorColor = Color(0xFFE74C3C);        // Red for Late/Error states
  static const Color darkGrey = Color(0xFF333333);          // Dark Grey for text
  
  // Background & Surface Colors
  static const Color backgroundColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color dividerColor = Color(0xFFE0E0E0);      // Light Grey for dividers
  
  // Text Colors
  static const Color primaryTextColor = Colors.black;
  static Color secondaryTextColor = Colors.grey[600]!;
  static Color tertiaryTextColor = Colors.grey[400]!;
  
  // Status Colors
  static const Color presentColor = Color(0xFF2CA01C);      // Green for Present
  static const Color lateColor = Color(0xFFE74C3C);         // Red for Late
  static const Color absentColor = Color(0xFF666666);       // Grey for Absent
  static const Color activeColor = Color(0xFF2CA01C);       // Green for Active
  
  // Filter Button Colors
  static const Color selectedFilterColor = Color(0xFF333333);
  static const Color unselectedFilterColor = Colors.white;
  static final Color filterBorderColor = Colors.grey[300]!;
  
  // Button Colors
  static const Color buttonPrimaryColor = Color(0xFF2CA01C);
  static const Color buttonTextColor = Colors.white;

  // Shadow
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.grey.withOpacity(0.2),
    spreadRadius: 1,
    blurRadius: 6,
    offset: const Offset(0, 3),
  );

  // Border Radius
  static final BorderRadius defaultBorderRadius = BorderRadius.circular(12);
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(50);
  
  // Text Styles
  
  // App Title Style
  static TextStyle appTitleStyle = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: primaryColor,
  );
  
  // Header Styles
  static TextStyle headerLargeStyle = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
  );
  
  static TextStyle headerMediumStyle = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
  );
  
  static TextStyle headerSmallStyle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
  );
  
  // Body Text Styles
  static TextStyle bodyLargeStyle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: primaryTextColor,
  );
  
  static TextStyle bodyMediumStyle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: primaryTextColor,
  );
  
  static TextStyle bodySmallStyle = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: secondaryTextColor,
  );
  
  // Specialized Styles
  static TextStyle dateStyle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: secondaryTextColor,
  );
  
  static TextStyle filterButtonStyle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  
  static TextStyle statsNumberStyle = GoogleFonts.poppins(
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle statsLabelStyle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: secondaryTextColor,
  );
  
  static TextStyle statsSubtitleStyle = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: secondaryTextColor,
  );
  
  // Button Styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: buttonPrimaryColor,
    foregroundColor: buttonTextColor,
    shape: RoundedRectangleBorder(
      borderRadius: buttonBorderRadius,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  );
  
  // Card Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: defaultBorderRadius,
    boxShadow: [cardShadow],
  );
  
  // Filter Button Decorations
  static BoxDecoration getFilterButtonDecoration(bool isSelected, String filter) {
    Color backgroundColor;
    
    if (isSelected) {
      switch (filter) {
        case 'Early':
          backgroundColor = presentColor;
          break;
        case 'Late':
          backgroundColor = lateColor;
          break;
        case 'Absent':
          backgroundColor = absentColor;
          break;
        default: // 'All' filter
          backgroundColor = selectedFilterColor;
      }
    } else {
      backgroundColor = unselectedFilterColor;
    }
    
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: buttonBorderRadius,
      border: Border.all(
        color: filterBorderColor,
      ),
    );
  }
  
  // Theme Data
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: backgroundColor,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      error: errorColor,
      background: backgroundColor,
      surface: cardColor,
      onPrimary: Colors.white,
      onSurface: primaryTextColor,
      secondary: primaryColor,
    ),
    dividerColor: dividerColor,
    textTheme: TextTheme(
      // Mapping standard text theme styles to our custom styles
      titleLarge: appTitleStyle, // App title
      titleMedium: headerMediumStyle, // Section headers
      bodyLarge: bodyLargeStyle, // Main body text
      bodyMedium: bodyMediumStyle, // Regular body text
      bodySmall: bodySmallStyle, // Captions and smaller text
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: defaultBorderRadius,
      ),
      color: cardColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: primaryColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headerLargeStyle,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryColor,
    ),
  );
}

/// Extension method to help access the theme more easily
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}