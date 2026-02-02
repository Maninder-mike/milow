import 'package:flutter/widgets.dart';

/// Utility class for optimizing image memory usage.
class ImageUtils {
  ImageUtils._();

  /// Default pixel density multiplier if context is not available.
  /// 3.0 covers most high-density screens (iPhone Pro, Pixel).
  static const double _defaultPixelRatio = 3.0;

  /// Calculates the optimal memory cache size for an image based on its display size
  /// and the device's pixel ratio.
  ///
  /// [displaySize] is the logical size (dp) of the image widget.
  /// [context] is optional. If provided, uses the actual device pixel ratio.
  static int getCacheSize(double displaySize, [BuildContext? context]) {
    final double pixelRatio = context != null
        ? MediaQuery.of(context).devicePixelRatio
        : _defaultPixelRatio;

    // Round to nearest integer
    return (displaySize * pixelRatio).round();
  }
}
