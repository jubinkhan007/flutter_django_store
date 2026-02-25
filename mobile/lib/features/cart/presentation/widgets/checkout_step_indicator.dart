import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/theme/app_motion.dart';

/// Animated horizontal 3-step progress indicator for checkout.
class CheckoutStepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const CheckoutStepIndicator({
    super.key,
    required this.currentStep,
    this.labels = const ['Address', 'Payment', 'Review'],
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (index) {
          // Even indices = step circles, odd indices = connectors
          if (index.isOdd) {
            final stepBefore = index ~/ 2;
            final isCompleted = stepBefore < currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: AppMotion.medium,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? primaryColor : AppColors.lightOutline,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isActive = stepIndex == currentStep;
          final isCompleted = stepIndex < currentStep;

          return _StepDot(
            label: labels[stepIndex],
            stepNumber: stepIndex + 1,
            isActive: isActive,
            isCompleted: isCompleted,
            primaryColor: primaryColor,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final int stepNumber;
  final bool isActive;
  final bool isCompleted;
  final Color primaryColor;

  const _StepDot({
    required this.label,
    required this.stepNumber,
    required this.isActive,
    required this.isCompleted,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.defaultCurve,
          width: isActive ? 36 : 28,
          height: isActive ? 36 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isActive
                ? primaryColor
                : AppColors.lightOutline,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryColor.withAlpha(64),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$stepNumber',
                    style: AppTextStyles.caption.copyWith(
                      color: isActive
                          ? Colors.white
                          : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isActive || isCompleted
                ? primaryColor
                : AppColors.lightTextSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
