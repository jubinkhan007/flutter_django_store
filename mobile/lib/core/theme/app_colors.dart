import 'package:flutter/material.dart';

class AppColors {
  // ── Light Theme Semantic Colors ──
  static const Color lightBg = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color surfaceLight = lightSurface;

  // Indigo / Coral Identity
  static const Color lightPrimary = Color(0xFF6366F1);
  static const Color lightAccent = Color(0xFFF43F5E); // Electric Coral

  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightMuted = Color(0xFF94A3B8); // Slate 400
  static const Color lightOutline = Color(0xFFE2E8F0); // Slate 200

  // ── Dark Theme Semantic Colors ──
  static const Color darkBg = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800

  // Lighter, neon-tinted identity for dark mode
  static const Color darkPrimary = Color(0xFF818CF8); // Indigo 400
  static const Color darkAccent = Color(0xFFFB7185); // Rose 400

  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkMuted = Color(0xFF64748B); // Slate 500
  static const Color darkOutline = Color(0xFF334155); // Slate 700

  // ── Universal Status Colors ──
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF3B82F6); // Blue 500
}
