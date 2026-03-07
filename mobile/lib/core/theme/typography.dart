import 'package:flutter/material.dart';

/// Centralized Typography Scale.
///
/// Note: We intentionally avoid runtime font fetching (e.g. google_fonts over HTTP),
/// so the app works in offline/dev environments and on emulators without DNS.
class AppTextStyles {
  static TextTheme get textTheme => ThemeData.light().textTheme;

  static TextStyle get titleLarge => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static TextStyle get titleMedium => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static TextStyle get bodyLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get labelLarge => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle get caption => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}
