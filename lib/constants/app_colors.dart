import 'package:flutter/material.dart';

class AppColors {
  // Primary Color - Yellow Accent (Premium Gold/Yellow)
  static const Color primary = Color(0xFFFFD700); // Premium Yellow
  static const Color primaryDark = Color(0xFFC5A300);
  static const Color primaryLight = Color(0xFFFFF1A8);
  
  // Uber-like Monochrome Palette
  static const Color uberBlack = Color(0xFF000000);
  static const Color uberWhite = Color(0xFFFFFFFF);
  static const Color uberGrey = Color(0xFFF1F1F1);
  static const Color uberGreyDark = Color(0xFF2D2D2D);
  static const Color uberGreyMedium = Color(0xFF8E8E93);
  static const Color uberGreyLight = Color(0xFFE5E5E5);

  // Success Colors
  static const Color success = Color(0xFF27AE60);
  static const Color successLight = Color(0xFFE8F6EF);

  // Error Colors
  static const Color error = Color(0xFFEB5757);
  static const Color errorLight = Color(0xFFFDEEEE);

  // Warning Colors
  static const Color warning = Color(0xFFF2994A);

  // Light Theme Colors (Uber Style)
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFEEEEEE);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightInputBg = Color(0xFFF6F6F6);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF545454);
  static const Color lightTextHint = Color(0xFFAFAFAF);
  static const Color lightIcon = Color(0xFF000000);
  static const Color lightShadow = Color(0x0A000000);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkDivider = Color(0xFF2D2D2D);
  static const Color darkBorder = Color(0xFF2D2D2D);
  static const Color darkInputBg = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAFAFAF);
  static const Color darkTextHint = Color(0xFF666666);
  static const Color darkIcon = Color(0xFFFFFFFF);
  static const Color darkShadow = Color(0x66000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [uberBlack, Color(0xFF1E1E1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // Status Colors
  static const Color online = Color(0xFF27AE60);
  static const Color offline = Color(0xFF8E8E93);

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
  static Color getShadowColor(bool isDark) => isDark ? (isDark ? darkShadow : lightShadow) : lightShadow;

  // Shimmer colors for loading
  static Color getShimmerBaseColor(bool isDark) => isDark ? Color(0xFF1E1E1E) : Color(0xFFE0E0E0);
  static Color getShimmerHighlightColor(bool isDark) => isDark ? Color(0xFF2D2D2D) : Color(0xFFF5F5F5);

  // Legacy compatibility colors
  static const Color successDark = Color(0xFF1E8449);
  static const Color warningDark = Color(0xFFD35400);
  static const Color errorDark = Color(0xFFC0392B);
  static const Color primaryAccent = Color(0xFFFF9800);
  static const Color secondary = Color(0xFF2196F3);
  static const Color secondaryDark = Color(0xFF1976D2);
  static const Color secondaryLight = Color(0xFF64B5F6);
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color mapRoute = Color(0xFF000000);
  static const Color mapPickup = Color(0xFF27AE60);
  static const Color mapDropoff = Color(0xFFEB5757);
  static const Color mapDriver = Color(0xFFFFD700);

  // Legacy getters for backward compatibility
  static Color get textDark => darkTextPrimary;
  static Color get textLight => lightTextPrimary;
  static Color get textMuted => lightTextHint;
  static Color get inputBg => lightInputBg;
  
  // Vehicle type colors
  static const Color smallVehicle = Color(0xFF4CAF50);
  static const Color sedanVehicle = Color(0xFF2196F3);
  static const Color largeVehicle = Color(0xFFFF9800);
}
