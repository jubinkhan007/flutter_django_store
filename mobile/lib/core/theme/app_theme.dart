import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'typography.dart';
import 'app_shadows.dart';

class AppTheme {
  static const Color error = AppColors.error;
  static const List<BoxShadow> softShadow = AppShadows.lightSoft;
  // ── Theme Data ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightAccent,
        surface: AppColors.lightSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
      ),
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor: AppColors.lightTextPrimary,
        displayColor: AppColors.lightTextPrimary,
      ),
      appBarTheme: _appBarTheme(AppColors.lightBg, AppColors.lightTextPrimary),
      cardTheme: _cardTheme(AppColors.lightSurface),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: AppColors.lightBg,
        borderColor: AppColors.lightOutline,
        focusColor: AppColors.lightPrimary,
        hintColor: AppColors.lightTextSecondary,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(AppColors.lightPrimary),
      bottomNavigationBarTheme: _bottomNavTheme(
        bgColor: AppColors.lightSurface,
        selectedColor: AppColors.lightPrimary,
        unselectedColor: AppColors.lightMuted,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightOutline,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkAccent,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
      ),
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
      appBarTheme: _appBarTheme(AppColors.darkBg, AppColors.darkTextPrimary),
      cardTheme: _cardTheme(AppColors.darkSurface),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: AppColors.darkSurface,
        borderColor: AppColors.darkOutline,
        focusColor: AppColors.darkPrimary,
        hintColor: AppColors.darkTextSecondary,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(AppColors.darkPrimary),
      bottomNavigationBarTheme: _bottomNavTheme(
        bgColor: AppColors.darkSurface,
        selectedColor: AppColors.darkPrimary,
        unselectedColor: AppColors.darkMuted,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkOutline,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ── Component Themes ──
  static AppBarTheme _appBarTheme(Color bgColor, Color fgColor) {
    return AppBarTheme(
      backgroundColor: bgColor,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent, // Prevents Material 3 tinting
      titleTextStyle: AppTextStyles.titleMedium.copyWith(color: fgColor),
      iconTheme: IconThemeData(color: fgColor),
    );
  }

  static CardThemeData _cardTheme(Color surfaceColor) {
    return CardThemeData(
      color: surfaceColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required Color fillColor,
    required Color borderColor,
    required Color focusColor,
    required Color hintColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: hintColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: focusColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(Color primaryColor) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        textStyle: AppTextStyles.labelLarge,
      ),
    );
  }

  static BottomNavigationBarThemeData _bottomNavTheme({
    required Color bgColor,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    return BottomNavigationBarThemeData(
      backgroundColor: bgColor,
      selectedItemColor: selectedColor,
      unselectedItemColor: unselectedColor,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextStyles.caption,
    );
  }
}
