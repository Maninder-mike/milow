import 'package:animations/animations.dart';
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

  /// Overshoot curve for emphasis effects
  static const Curve overshoot = Curves.easeOutBack;

  /// Anticipate curve - slight pullback before action
  static const Curve anticipate = Curves.easeInBack;

  // ============= PHYSICS-BASED SPRINGS =============

  /// Gentle spring for subtle, natural movements
  static const SpringDescription gentleSpring = SpringDescription(
    mass: 1.0,
    stiffness: 100.0,
    damping: 15.0,
  );

  /// Bouncy spring for playful, energetic animations
  static const SpringDescription bouncySpring = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 10.0,
  );

  /// Stiff spring for quick, responsive feedback
  static const SpringDescription stiffSpring = SpringDescription(
    mass: 1.0,
    stiffness: 500.0,
    damping: 25.0,
  );

  /// Slow spring for dramatic, cinematic effects
  static const SpringDescription slowSpring = SpringDescription(
    mass: 1.5,
    stiffness: 50.0,
    damping: 12.0,
  );

  // ============= SHARED AXIS TYPES =============

  /// Horizontal shared axis (left-right navigation)
  static const SharedAxisTransitionType sharedAxisHorizontal =
      SharedAxisTransitionType.horizontal;

  /// Vertical shared axis (up-down navigation)
  static const SharedAxisTransitionType sharedAxisVertical =
      SharedAxisTransitionType.vertical;

  /// Scaled shared axis (zoom in/out navigation)
  static const SharedAxisTransitionType sharedAxisScaled =
      SharedAxisTransitionType.scaled;

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

  // ============= ACCESSIBILITY =============

  /// Check if user prefers reduced motion
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get duration respecting reduced motion preference
  static Duration getAccessibleDuration(
    BuildContext context,
    Duration normalDuration,
  ) {
    return shouldReduceMotion(context) ? Duration.zero : normalDuration;
  }

  /// Get curve respecting reduced motion preference
  static Curve getAccessibleCurve(BuildContext context, Curve normalCurve) {
    return shouldReduceMotion(context) ? Curves.linear : normalCurve;
  }

  // ============= CONTAINER TRANSFORM =============

  /// Creates a container transform page route (card expanding to full screen)
  static Route<T> containerTransformRoute<T>({
    required Widget Function(BuildContext, Animation<double>, Animation<double>)
    pageBuilder,
    Color? backgroundColor,
    Duration duration = durationEmphasis,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          pageBuilder(context, animation, secondaryAnimation),
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          fillColor: backgroundColor ?? Colors.transparent,
          child: child,
        );
      },
    );
  }

  // ============= SHARED AXIS TRANSITIONS =============

  /// Creates a shared axis page route
  static Route<T> sharedAxisRoute<T>({
    required Widget page,
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
    Duration duration = durationMedium,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          child: child,
        );
      },
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

  /// Calculates staggered delay for grid animations
  static Duration staggeredDelay(int index, {int columns = 2}) {
    final row = index ~/ columns;
    final col = index % columns;
    final diagonalIndex = row + col;
    return Duration(milliseconds: diagonalIndex * 50);
  }

  /// Creates staggered animation controller delays
  static List<Duration> staggeredDelays(
    int count, {
    Duration gap = const Duration(milliseconds: 50),
  }) {
    return List.generate(
      count,
      (i) => Duration(milliseconds: i * gap.inMilliseconds),
    );
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

/// A wrapper for OpenContainer that expands a card into a full-screen detail page
/// Enterprise-grade container transform animation
class M3ContainerTransform extends StatelessWidget {
  /// The closed (thumbnail/card) widget builder
  final Widget Function(BuildContext, VoidCallback) closedBuilder;

  /// The open (full-screen detail) widget builder
  final Widget Function(BuildContext, VoidCallback) openBuilder;

  /// Background color during the transition
  final Color? transitionBackgroundColor;

  /// Border radius of the closed container
  final BorderRadius closedBorderRadius;

  /// Duration of the animation
  final Duration transitionDuration;

  /// Elevation of the closed container
  final double closedElevation;

  /// Elevation of the open container
  final double openElevation;

  const M3ContainerTransform({
    required this.closedBuilder,
    required this.openBuilder,
    super.key,
    this.transitionBackgroundColor,
    this.closedBorderRadius = const BorderRadius.all(Radius.circular(16)),
    this.transitionDuration = M3ExpressiveMotion.durationEmphasis,
    this.closedElevation = 0,
    this.openElevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = M3ExpressiveMotion.shouldReduceMotion(context);

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: reduceMotion ? Duration.zero : transitionDuration,
      openBuilder: (context, action) => openBuilder(context, action),
      closedBuilder: (context, action) => closedBuilder(context, action),
      closedShape: RoundedRectangleBorder(borderRadius: closedBorderRadius),
      closedElevation: closedElevation,
      openElevation: openElevation,
      closedColor:
          transitionBackgroundColor ?? Theme.of(context).colorScheme.surface,
      openColor:
          transitionBackgroundColor ?? Theme.of(context).colorScheme.surface,
    );
  }
}

/// A widget that staggers child animations in a list
class M3StaggeredList extends StatefulWidget {
  /// The list of children to animate
  final List<Widget> children;

  /// Main axis direction
  final Axis direction;

  /// Main axis alignment
  final MainAxisAlignment mainAxisAlignment;

  /// Cross axis alignment
  final CrossAxisAlignment crossAxisAlignment;

  /// Spacing between items
  final double spacing;

  /// Delay between each item's animation start
  final Duration staggerDelay;

  /// Duration of each item's animation
  final Duration itemDuration;

  const M3StaggeredList({
    required this.children,
    super.key,
    this.direction = Axis.vertical,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = 0,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.itemDuration = M3ExpressiveMotion.durationMedium,
  });

  @override
  State<M3StaggeredList> createState() => _M3StaggeredListState();
}

class _M3StaggeredListState extends State<M3StaggeredList> {
  @override
  Widget build(BuildContext context) {
    final reduceMotion = M3ExpressiveMotion.shouldReduceMotion(context);

    final animatedChildren = widget.children.asMap().entries.map((entry) {
      final index = entry.key;
      final child = entry.value;

      if (reduceMotion) return child;

      return M3ExpressiveEntrance(
        delay: Duration(
          milliseconds: index * widget.staggerDelay.inMilliseconds,
        ),
        duration: widget.itemDuration,
        child: child,
      );
    }).toList();

    if (widget.direction == Axis.horizontal) {
      return Row(
        mainAxisAlignment: widget.mainAxisAlignment,
        crossAxisAlignment: widget.crossAxisAlignment,
        children: _addSpacing(
          animatedChildren,
          widget.spacing,
          Axis.horizontal,
        ),
      );
    }

    return Column(
      mainAxisAlignment: widget.mainAxisAlignment,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: _addSpacing(animatedChildren, widget.spacing, Axis.vertical),
    );
  }

  List<Widget> _addSpacing(List<Widget> children, double spacing, Axis axis) {
    if (spacing == 0 || children.isEmpty) return children;

    final spacer = axis == Axis.vertical
        ? SizedBox(height: spacing)
        : SizedBox(width: spacing);

    return children
        .expand((child) => [child, spacer])
        .take(children.length * 2 - 1)
        .toList();
  }
}
