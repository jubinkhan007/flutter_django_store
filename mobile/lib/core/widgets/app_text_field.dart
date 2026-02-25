import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final dynamic prefixIcon;
  final dynamic suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;

  const AppTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    // The visual styling is universally handled by the InputDecorationTheme
    // configured in app_theme.dart! This widget acts as a clean, standardized
    // wrapper to ensure consistency.
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon is IconData
            ? Icon(prefixIcon, size: 20, color: AppColors.lightTextSecondary)
            : prefixIcon,
        suffixIcon: suffixIcon is IconData
            ? Icon(suffixIcon, size: 20, color: AppColors.lightTextSecondary)
            : suffixIcon,
      ),
    );
  }
}
