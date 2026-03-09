import 'package:flutter/material.dart';

/// AppConfig is the central point for white-labeling the application.
/// Buyers can change these values to instantly rebrand the app without
/// having to search through the entire codebase.
class AppConfig {
  // ---------------------------------------------------------------------------
  // 1. BRANDING & IDENTITY
  // ---------------------------------------------------------------------------

  /// The name of the application (used in the App Bar, Titles, etc.)
  static const String appName = 'ShopEase';

  /// A short tagline or description for the store
  static const String appTagline = 'Your Premium Shopping Experience';

  // ---------------------------------------------------------------------------
  // 2. THEME & COLORS
  // ---------------------------------------------------------------------------

  /// The primary color of the application (buttons, active states, branding)
  static const Color primaryColor = Color(0xFF6366F1); // Indigo 500

  /// The secondary/accent color
  static const Color accentColor = Color(0xFF14B8A6); // Teal 500

  // ---------------------------------------------------------------------------
  // 3. API & BACKEND CONNECTION
  // ---------------------------------------------------------------------------

  /// The production URL of your Django backend API.
  /// Example: 'https://yourdomain.com/api'
  static const String backendApiUrl = 'https://shopease.chickenkiller.com/api';

  /// For local development using an Android Emulator, use this:
  static const String localAndroidApiUrl = 'http://10.0.2.2:8000/api';

  /// For local development using iOS Simulator or Web, use this:
  static const String localIosApiUrl = 'http://localhost:8000/api';

  /// Set this to true when publishing the app. It forces the use of [backendApiUrl].
  /// Set to false during development to use local URLs.
  static const bool isProduction = true;

  // ---------------------------------------------------------------------------
  // 4. E-COMMERCE SETTINGS
  // ---------------------------------------------------------------------------

  /// The default currency symbol used throughout the app
  static const String currencySymbol = '\$';

  /// The default currency code (e.g., USD, EUR, GBP)
  static const String currencyCode = 'USD';
}
