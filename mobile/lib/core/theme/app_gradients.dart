import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  static const LinearGradient lightPrimary = LinearGradient(
    colors: [
      AppColors.lightPrimary,
      Color(0xFF818CF8),
    ], // Indigo 500 to Indigo 400
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkPrimary = LinearGradient(
    colors: [
      AppColors.darkPrimary,
      Color(0xFFA5B4FC),
    ], // Indigo 400 to Indigo 300
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightAccent = LinearGradient(
    colors: [AppColors.lightAccent, Color(0xFFFB7185)], // Rose 500 to Rose 400
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient darkAccent = LinearGradient(
    colors: [AppColors.darkAccent, Color(0xFFFDA4AF)], // Rose 400 to Rose 300
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
}
