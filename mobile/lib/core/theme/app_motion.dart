import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppMotion {
  // ── Durations ──
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  // ── Curves ──
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bouncyCurve = Curves.elasticOut;

  // ── Stagger Constants ──
  static const Duration listStagger = Duration(milliseconds: 50);

  // ── Global Standard Effects ──

  /// Standard fade and slight slide up (common for lists and new content)
  static Animate fadeSlideY(
    Widget child, {
    Duration? duration,
    Duration? delay,
  }) {
    return child
        .animate(delay: delay)
        .fade(duration: duration ?? medium, curve: defaultCurve)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: duration ?? medium,
          curve: defaultCurve,
        );
  }

  /// Standard subtle scale-down on press (used for buttons and cards)
  static final pressScale = 0.98;
}
