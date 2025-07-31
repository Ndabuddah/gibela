import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Yellow Theme
  static const Color primary = Color(0xFFFFD700); // Bright Yellow
  static const Color primaryDark = Color(0xFFFFC107); // Darker Yellow
  static const Color primaryLight = Color(0xFFFFEB3B); // Light Yellow
  static const Color primaryAccent = Color(0xFFFF9800); // Orange Yellow

  // Secondary Colors
  static const Color secondary = Color(0xFF2196F3); // Blue
  static const Color secondaryDark = Color(0xFF1976D2);
  static const Color secondaryLight = Color(0xFF64B5F6);

  // Success Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDark = Color(0xFF388E3C);

  // Error Colors
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFE57373);
  static const Color errorDark = Color(0xFFD32F2F);

  // Warning Colors
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFF57C00);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightInputBg = Color(0xFFF5F5F5);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightTextHint = Color(0xFFBDBDBD);
  static const Color lightIcon = Color(0xFF757575);
  static const Color lightShadow = Color(0x1A000000);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkDivider = Color(0xFF424242);
  static const Color darkBorder = Color(0xFF424242);
  static const Color darkInputBg = Color(0xFF2D2D2D);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  static const Color darkTextHint = Color(0xFF666666);
  static const Color darkIcon = Color(0xFFB3B3B3);
  static const Color darkShadow = Color(0x40000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [error, errorDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glass Effect Colors
  static const Color glassLight = Color(0x80FFFFFF);
  static const Color glassDark = Color(0x80000000);

  // Status Colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color busy = Color(0xFFFF9800);
  static const Color away = Color(0xFFFFC107);

  // Map Colors
  static const Color mapRoute = Color(0xFF2196F3);
  static const Color mapPickup = Color(0xFF4CAF50);
  static const Color mapDropoff = Color(0xFFF44336);
  static const Color mapDriver = Color(0xFFFFD700);

  // Animation Colors
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color shimmerDarkBase = Color(0xFF424242);
  static const Color shimmerDarkHighlight = Color(0xFF616161);

  // Add missing color getters for compatibility with usages in the app
  static const Color textLight = Colors.white;
  static const Color textDark = Color(0xFF333333);
  static const Color textMuted = Color(0xFF888888);
  static const Color inputBg = Color(0xFFF5F5F5);
  static const Color smallVehicle = Color(0xFFB0BEC5);
  static const Color sedanVehicle = Color(0xFF78909C);
  static const Color largeVehicle = Color(0xFF455A64);

  // Get theme-aware colors
  static Color getBackgroundColor(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color getSurfaceColor(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color getCardColor(bool isDark) => isDark ? darkCard : lightCard;
  static Color getDividerColor(bool isDark) => isDark ? darkDivider : lightDivider;
  static Color getBorderColor(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color getInputBgColor(bool isDark) => isDark ? darkInputBg : lightInputBg;
  static Color getTextPrimaryColor(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextSecondaryColor(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextHintColor(bool isDark) => isDark ? darkTextHint : lightTextHint;
  static Color getIconColor(bool isDark) => isDark ? darkIcon : lightIcon;
  static Color getShadowColor(bool isDark) => isDark ? darkShadow : lightShadow;
  static Color getShimmerBaseColor(bool isDark) => isDark ? shimmerDarkBase : shimmerBase;
  static Color getShimmerHighlightColor(bool isDark) => isDark ? shimmerDarkHighlight : shimmerHighlight;
}

//app theme

// lib/apptheme.dart

class AppTheme {
  // Main colors
  static const Color primaryColor = Color(0xFF5D5CDE); // Purple primary color
  static const Color secondaryColor = Color(0xFF00B36B); // Green secondary color
  static const Color accentColor = Color(0xFFF8C109); // Yellow accent

  // Background colors
  static const Color darkBackground = Color(0xFF121212); // Main dark background
  static const Color darkerBackground = Color(0xFF1E1E1E); // Darker elements

  // Text colors
  static const Color textLight = Colors.white;
  static const Color greyText = Color(0xFF8E8E93); // Secondary text
  static const Color textDark = Color(0xFF333333); // For light mode

  // Status colors
  static const Color success = Color(0xFF2ECC71); // Green for success states
  static const Color warning = Color(0xFFFFD700); // Yellow for warnings
  static const Color error = Color(0xFFE74C3C); // Red for errors
  static const Color info = Color(0xFF3498DB); // Blue for information

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5D5CDE), Color(0xFF7A79E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textLight,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textLight,
  );

  static const TextStyle subTitleStyle = TextStyle(
    fontSize: 16,
    color: greyText,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 14,
    color: textLight,
    height: 1.5,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: greyText,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textLight,
  );

  // Specific text styles used in the app
  static const TextStyle nameStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textLight,
  );

  static const TextStyle timeStyle = TextStyle(
    fontSize: 12,
    color: greyText,
  );

  static const TextStyle recentNameStyle = TextStyle(
    fontSize: 12,
    color: textLight,
    fontWeight: FontWeight.w500,
  );

  // Card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: darkerBackground,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );

  // Input decoration
  static InputDecoration inputDecoration({
    String? hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconTap,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: greyText),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: greyText) : null,
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: greyText),
              onPressed: onSuffixIconTap,
            )
          : null,
      filled: true,
      fillColor: darkerBackground,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // Button styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: textLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    textStyle: buttonTextStyle,
  );

  static ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: BorderSide(color: primaryColor),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    textStyle: buttonTextStyle.copyWith(color: primaryColor),
  );

  // ThemeData for light and dark themes
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      background: Colors.white,
      surface: Colors.white,
      onBackground: textDark,
      onSurface: textDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textDark,
      elevation: 0,
    ),
    fontFamily: 'Poppins',
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      background: darkBackground,
      surface: darkerBackground,
      onBackground: textLight,
      onSurface: textLight,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkerBackground,
      foregroundColor: textLight,
      elevation: 0,
    ),
    fontFamily: 'Poppins',
  );
}
