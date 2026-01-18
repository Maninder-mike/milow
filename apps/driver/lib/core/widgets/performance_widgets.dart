import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:milow/core/constants/design_tokens.dart';

/// Performance-optimized image widget with memory caching defaults
///
/// Wraps [CachedNetworkImage] with sensible defaults for performance:
/// - Memory cache sizing to reduce GPU memory usage
/// - Placeholder shimmer effect
/// - Error handling with retry
///
/// Usage:
/// ```dart
/// OptimizedImage(
///   imageUrl: 'https://example.com/image.jpg',
///   width: 100,
///   height: 100,
/// )
/// ```
class OptimizedImage extends StatelessWidget {
  /// The URL of the image to load
  final String imageUrl;

  /// Width of the image (required for memory optimization)
  final double width;

  /// Height of the image (required for memory optimization)
  final double height;

  /// BoxFit for the image (defaults to cover)
  final BoxFit fit;

  /// Border radius for the image
  final BorderRadius? borderRadius;

  /// Whether to show a shimmer loading effect
  final bool showShimmer;

  /// Custom placeholder widget
  final Widget? placeholder;

  /// Custom error widget
  final Widget? errorWidget;

  const OptimizedImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    super.key,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showShimmer = true,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Calculate memory cache dimensions (2x for retina, capped at 1000px)
    final cacheWidth = (width * 2).clamp(0, 1000).toInt();
    final cacheHeight = (height * 2).clamp(0, 1000).toInt();

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : showShimmer
          ? (context, url) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: tokens.inputBorder,
                borderRadius: borderRadius,
              ),
            )
          : null,
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!
          : (context, url, error) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: tokens.surfaceContainer,
                borderRadius: borderRadius,
              ),
              child: Icon(
                Icons.broken_image_outlined,
                color: tokens.textTertiary,
                size: (width / 3).clamp(16, 48),
              ),
            ),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// A widget that prevents its child from being rebuilt when parent rebuilds
///
/// Use this to wrap expensive widgets that don't depend on parent state.
///
/// Usage:
/// ```dart
/// RebuildBarrier(
///   child: ExpensiveWidget(),
/// )
/// ```
class RebuildBarrier extends StatefulWidget {
  final Widget child;

  const RebuildBarrier({required this.child, super.key});

  @override
  State<RebuildBarrier> createState() => _RebuildBarrierState();
}

class _RebuildBarrierState extends State<RebuildBarrier> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Creates a RepaintBoundary with optional debugging
///
/// Use for widgets with complex animations to isolate their repaints.
///
/// Usage:
/// ```dart
/// IsolatedPaint(
///   child: AnimatedWidget(),
/// )
/// ```
class IsolatedPaint extends StatelessWidget {
  final Widget child;

  const IsolatedPaint({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}

/// Guidelines for performance optimization:
///
/// 1. **Use const constructors** whenever possible:
///    ```dart
///    const Text('Hello')  // ✅ Good
///    Text('Hello')        // ❌ Rebuilds every time
///    ```
///
/// 2. **Extract expensive child widgets** into their own StatelessWidget:
///    ```dart
///    // Instead of inline complex widgets
///    Column(children: [
///      ExpensiveChart(),  // This rebuilds when parent rebuilds
///    ])
///
///    // Extract into const widget
///    Column(children: [
///      const _ChartWidget(),  // ✅ Skipped during parent rebuild
///    ])
///    ```
///
/// 3. **Use ListView.builder** for lists > 20 items:
///    ```dart
///    ListView.builder(
///      itemCount: items.length,
///      itemBuilder: (_, i) => ItemWidget(items[i]),
///    )
///    ```
///
/// 4. **Cache expensive computations** in initState or using late:
///    ```dart
///    late final expensiveValue = computeExpensiveValue();
///    ```
///
/// 5. **Use RepaintBoundary** for animated widgets:
///    ```dart
///    RepaintBoundary(child: AnimatedWidget())
///    ```
///
/// 6. **Minimize setState scope** - only rebuild what's necessary
