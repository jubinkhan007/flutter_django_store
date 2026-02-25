import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/typography.dart';

class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGradient = isDark
        ? AppGradients.darkPrimary
        : AppGradients.lightPrimary;
    final primaryColor = isDark
        ? AppColors.darkPrimary
        : AppColors.lightPrimary;
    final glowShadow = isDark
        ? AppShadows.darkGlowPrimary
        : AppShadows.lightGlowPrimary;

    final isDisabled = widget.onPressed == null || widget.isLoading;

    Widget buttonContent = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.outlined ? primaryColor : Colors.white,
            ),
          )
        : Text(
            widget.text,
            style: AppTextStyles.labelLarge.copyWith(
              color: widget.outlined ? primaryColor : Colors.white,
              fontSize: 16,
            ),
          );

    if (widget.outlined) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: isDisabled ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isDisabled ? AppColors.lightMuted : primaryColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          child: buttonContent,
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) {
        if (!isDisabled) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (!isDisabled) setState(() => _isPressed = false);
      },
      onTapCancel: () {
        if (!isDisabled) setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? AppMotion.pressScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.defaultCurve,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isDisabled ? null : primaryGradient,
              color: isDisabled
                  ? (isDark ? AppColors.darkOutline : AppColors.lightMuted)
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: (isDisabled || _isPressed) ? null : glowShadow,
            ),
            child: ElevatedButton(
              onPressed: isDisabled ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              child: buttonContent,
            ),
          ),
        ),
      ),
    );
  }
}
