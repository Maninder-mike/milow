import 'package:flutter/material.dart';

/// Material 3 Expressive Motion Utilities
///
/// Implements the M3 Expressive motion-physics system for natural,
/// fluid animations that feel alive and responsive.
///
/// Reference: https://m3.material.io/blog/building-with-m3-expressive
class M3ExpressiveMotion {
  M3ExpressiveMotion._();

  // ============= CURVES =============

  /// Standard curve for most animations
  static const Curve standard = Curves.easeInOutCubicEmphasized;

  /// Emphasized curve for dramatic transitions (page navigation, dialogs)
  static const Curve emphasized = Curves.easeOutExpo;

  /// Decelerated curve for elements entering the screen
  static const Curve decelerated = Curves.easeOutCubic;

  /// Accelerated curve for elements leaving the screen
  static const Curve accelerated = Curves.easeInCubic;

  /// Spring-like curve for bouncy, playful animations
  static const Curve spring = Curves.elasticOut;

  // ============= DURATIONS =============

  /// Short duration for micro-interactions (50-150ms)
  static const Duration durationShort = Duration(milliseconds: 150);

  /// Medium duration for most transitions (200-300ms)
  static const Duration durationMedium = Duration(milliseconds: 300);

  /// Long duration for complex transitions (400-500ms)
  static const Duration durationLong = Duration(milliseconds: 500);

  /// Emphasis duration for dramatic transitions (600-800ms)
  static const Duration durationEmphasis = Duration(milliseconds: 700);

  // ============= ANIMATION BUILDERS =============

  /// Creates a fade + scale animation for modal presentations
  static Widget fadeScale({
    required Animation<double> animation,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: emphasized)),
        child: child,
      ),
    );
  }

  /// Creates a slide + fade animation for list items
  static Widget slideUp({
    required Animation<double> animation,
    required Widget child,
    double offset = 20,
  }) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, offset / 100),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: decelerated)),
        child: child,
      ),
    );
  }

  /// Creates an emphasis scale animation for buttons/tappable elements
  static Widget emphasisScale({
    required Animation<double> animation,
    required Widget child,
  }) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1.0,
        end: 0.95,
      ).animate(CurvedAnimation(parent: animation, curve: standard)),
      child: child,
    );
  }

  // ============= STAGGERED ANIMATIONS =============

  /// Calculates staggered interval for list animations
  static Interval staggeredInterval(int index, int total) {
    const double start = 0.0;
    const double end = 0.8;
    final double itemGap = (end - start) / total.clamp(1, 20);
    final double itemStart = start + (index * itemGap);
    final double itemEnd = (itemStart + 0.3).clamp(0.0, 1.0);
    return Interval(itemStart, itemEnd, curve: decelerated);
  }
}

/// Extension for easy access to M3 Expressive motion constants
extension M3ExpressiveThemeExtension on ThemeData {
  /// Standard M3 Expressive transition duration
  Duration get transitionDuration => M3ExpressiveMotion.durationMedium;

  /// Emphasis M3 Expressive transition duration
  Duration get emphasisDuration => M3ExpressiveMotion.durationEmphasis;

  /// Standard M3 Expressive curve
  Curve get transitionCurve => M3ExpressiveMotion.standard;

  /// Emphasis M3 Expressive curve
  Curve get emphasisCurve => M3ExpressiveMotion.emphasized;
}

/// A widget that applies M3 Expressive entrance animation
class M3ExpressiveEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  const M3ExpressiveEntrance({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = M3ExpressiveMotion.durationMedium,
    this.curve = M3ExpressiveMotion.decelerated,
  });

  @override
  State<M3ExpressiveEntrance> createState() => _M3ExpressiveEntranceState();
}

class _M3ExpressiveEntranceState extends State<M3ExpressiveEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
