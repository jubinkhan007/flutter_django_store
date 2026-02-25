import 'package:flutter/material.dart';

class AppShadows {
  // Light Theme Shadows
  static const List<BoxShadow> lightSoft = [
    BoxShadow(
      color: Color(0x0A0F172A), // Very subtle Slate 900
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
    BoxShadow(color: Color(0x050F172A), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> lightGlowPrimary = [
    BoxShadow(
      color: Color(0x406366F1), // Indigo glow
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // Dark Theme Shadows (Much subtler, mostly relying on outlines as per user request)
  static const List<BoxShadow> darkSoft = [
    BoxShadow(
      color: Color(0x80000000), // Pure black shadow, lower opacity
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> darkGlowPrimary = [
    BoxShadow(
      color: Color(0x40818CF8), // Light Indigo glow
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];
}
