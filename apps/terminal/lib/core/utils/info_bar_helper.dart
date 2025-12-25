import 'package:fluent_ui/fluent_ui.dart';

/// Displays an InfoBar notification in the bottom-right corner.
/// This is a wrapper around Fluent UI's displayInfoBar with consistent positioning.
void showInfoBar(
  BuildContext context, {
  required Widget Function(BuildContext, void Function()) builder,
  Duration duration = const Duration(seconds: 3),
}) {
  displayInfoBar(
    context,
    alignment: Alignment.bottomRight,
    duration: duration,
    builder: builder,
  );
}
