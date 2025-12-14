import 'package:flutter/material.dart';

/// Material Design 2 Responsive Layout Grid
/// Based on: https://m2.material.io/design/layout/responsive-layout-grid.html
///
/// Breakpoints:
/// - Extra-small (phone): 0-599dp, 4 columns, 16dp margins, 16dp gutters
/// - Small (tablet): 600-904dp, 8 columns, 32dp margins, 24dp gutters
/// - Small-medium: 905-1239dp, 12 columns, scaling margins (840dp body), 24dp gutters
/// - Medium (laptop): 1240-1439dp, 12 columns, 200dp margins, 24dp gutters
/// - Large (desktop): 1440+dp, 12 columns, scaling margins (1040dp body), 24dp gutters

enum ScreenSize { xs, sm, md, lg, xl }

class ResponsiveLayout {
  /// Get the current screen size category based on width
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return getScreenSizeFromWidth(width);
  }

  /// Get screen size from width value
  static ScreenSize getScreenSizeFromWidth(double width) {
    if (width < 600) return ScreenSize.xs;
    if (width < 905) return ScreenSize.sm;
    if (width < 1240) return ScreenSize.md;
    if (width < 1440) return ScreenSize.lg;
    return ScreenSize.xl;
  }

  /// Get number of columns for current screen size
  static int getColumns(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.xs:
        return 4;
      case ScreenSize.sm:
        return 8;
      case ScreenSize.md:
      case ScreenSize.lg:
      case ScreenSize.xl:
        return 12;
    }
  }

  /// Get margin width for current screen size
  static double getMargin(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final size = getScreenSizeFromWidth(width);

    switch (size) {
      case ScreenSize.xs:
        return 16.0;
      case ScreenSize.sm:
        return 32.0;
      case ScreenSize.md:
        // Scaling margins with 840dp max body width
        final bodyWidth = 840.0;
        final margin = (width - bodyWidth) / 2;
        return margin.clamp(32.0, 200.0);
      case ScreenSize.lg:
        return 200.0;
      case ScreenSize.xl:
        // Scaling margins with 1040dp max body width
        final bodyWidth = 1040.0;
        final margin = (width - bodyWidth) / 2;
        return margin.clamp(200.0, double.infinity);
    }
  }

  /// Get gutter width for current screen size
  static double getGutter(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.xs:
        return 16.0;
      case ScreenSize.sm:
      case ScreenSize.md:
      case ScreenSize.lg:
      case ScreenSize.xl:
        return 24.0;
    }
  }

  /// Get the maximum body width for current screen size
  static double? getMaxBodyWidth(BuildContext context) {
    final size = getScreenSize(context);
    switch (size) {
      case ScreenSize.xs:
      case ScreenSize.sm:
        return null; // Scaling
      case ScreenSize.md:
        return 840.0;
      case ScreenSize.lg:
        return null; // Scaling
      case ScreenSize.xl:
        return 1040.0;
    }
  }

  /// Check if screen is mobile-sized
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.xs;
  }

  /// Check if screen is tablet-sized
  static bool isTablet(BuildContext context) {
    final size = getScreenSize(context);
    return size == ScreenSize.sm || size == ScreenSize.md;
  }

  /// Check if screen is desktop-sized
  static bool isDesktop(BuildContext context) {
    final size = getScreenSize(context);
    return size == ScreenSize.lg || size == ScreenSize.xl;
  }

  /// Get horizontal padding for content
  static EdgeInsets getHorizontalPadding(BuildContext context) {
    final margin = getMargin(context);
    return EdgeInsets.symmetric(horizontal: margin);
  }

  /// Get symmetric padding (horizontal margins)
  static EdgeInsets getSymmetricPadding(
    BuildContext context, {
    double vertical = 0,
  }) {
    final margin = getMargin(context);
    return EdgeInsets.symmetric(horizontal: margin, vertical: vertical);
  }
}

/// A responsive container that applies Material Design margins
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final bool center;

  const ResponsiveContainer({
    required this.child, super.key,
    this.maxWidth,
    this.padding,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    final margin = ResponsiveLayout.getMargin(context);
    final effectiveMaxWidth =
        maxWidth ?? ResponsiveLayout.getMaxBodyWidth(context);

    Widget content = child;

    if (effectiveMaxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: content,
      );
    }

    if (center) {
      content = Center(child: content);
    }

    return Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: margin),
      child: content,
    );
  }
}

/// A responsive grid that adapts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? columns;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    required this.children, super.key,
    this.columns,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.childAspectRatio = 1.0,
    this.padding,
    this.shrinkWrap = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = ResponsiveLayout.getGutter(context);
    final margin = ResponsiveLayout.getMargin(context);
    final effectiveColumns = columns ?? ResponsiveLayout.getColumns(context);

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.symmetric(horizontal: margin),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveColumns,
        mainAxisSpacing: mainAxisSpacing ?? gutter,
        crossAxisSpacing: crossAxisSpacing ?? gutter,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// A responsive row that wraps items with appropriate spacing
class ResponsiveRow extends StatelessWidget {
  final List<ResponsiveColumn> children;
  final WrapAlignment alignment;
  final WrapAlignment runAlignment;
  final double? spacing;
  final double? runSpacing;

  const ResponsiveRow({
    required this.children, super.key,
    this.alignment = WrapAlignment.start,
    this.runAlignment = WrapAlignment.start,
    this.spacing,
    this.runSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = ResponsiveLayout.getGutter(context);
    final totalColumns = ResponsiveLayout.getColumns(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final margin = ResponsiveLayout.getMargin(context);
    final availableWidth = screenWidth - (margin * 2);
    final columnWidth =
        (availableWidth - (gutter * (totalColumns - 1))) / totalColumns;

    return Wrap(
      alignment: alignment,
      runAlignment: runAlignment,
      spacing: spacing ?? gutter,
      runSpacing: runSpacing ?? gutter,
      children: children.map((col) {
        final span = col.getSpan(context, totalColumns);
        final width = (columnWidth * span) + (gutter * (span - 1));
        return SizedBox(width: width, child: col.child);
      }).toList(),
    );
  }
}

/// A column within a ResponsiveRow
class ResponsiveColumn extends StatelessWidget {
  final Widget child;
  final int? xs; // 0-599dp: 4 columns
  final int? sm; // 600-904dp: 8 columns
  final int? md; // 905-1239dp: 12 columns
  final int? lg; // 1240-1439dp: 12 columns
  final int? xl; // 1440+dp: 12 columns

  const ResponsiveColumn({
    required this.child, super.key,
    this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
  });

  int getSpan(BuildContext context, int totalColumns) {
    final size = ResponsiveLayout.getScreenSize(context);

    switch (size) {
      case ScreenSize.xs:
        return (xs ?? totalColumns).clamp(1, totalColumns);
      case ScreenSize.sm:
        return (sm ?? xs ?? totalColumns).clamp(1, totalColumns);
      case ScreenSize.md:
        return (md ?? sm ?? xs ?? totalColumns).clamp(1, totalColumns);
      case ScreenSize.lg:
        return (lg ?? md ?? sm ?? xs ?? totalColumns).clamp(1, totalColumns);
      case ScreenSize.xl:
        return (xl ?? lg ?? md ?? sm ?? xs ?? totalColumns).clamp(
          1,
          totalColumns,
        );
    }
  }

  @override
  Widget build(BuildContext context) => child;
}

/// A builder widget for responsive layouts
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    ScreenSize size,
    BoxConstraints constraints,
  )
  builder;

  const ResponsiveBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ResponsiveLayout.getScreenSize(context);
        return builder(context, size, constraints);
      },
    );
  }
}

/// Extension for easier responsive value selection
extension ResponsiveValue<T> on BuildContext {
  /// Select a value based on screen size
  T responsive({required T xs, T? sm, T? md, T? lg, T? xl}) {
    final size = ResponsiveLayout.getScreenSize(this);

    switch (size) {
      case ScreenSize.xs:
        return xs;
      case ScreenSize.sm:
        return sm ?? xs;
      case ScreenSize.md:
        return md ?? sm ?? xs;
      case ScreenSize.lg:
        return lg ?? md ?? sm ?? xs;
      case ScreenSize.xl:
        return xl ?? lg ?? md ?? sm ?? xs;
    }
  }
}
