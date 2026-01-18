import 'package:fluent_ui/fluent_ui.dart';
import '../widgets/toast_notification.dart';

/// Displays a Fluent 2 styled toast notification.
///
/// This is a wrapper around [showFluentToast] with consistent positioning
/// and simplified API for common use cases.
///
/// For more control, use [showFluentToast] directly.
void showInfoBar(
  BuildContext context, {
  required String title,
  String? message,
  InfoBarSeverity severity = InfoBarSeverity.info,
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onAction,
  String? actionLabel,
}) {
  showFluentToast(
    context,
    title: title,
    body: message,
    intent: _severityToIntent(severity),
    duration: duration,
    action: onAction != null && actionLabel != null
        ? ToastAction(label: actionLabel, onPressed: onAction)
        : null,
  );
}

/// Displays a success toast notification.
void showSuccessToast(
  BuildContext context, {
  required String title,
  String? message,
  Duration duration = const Duration(seconds: 4),
}) {
  showFluentToast(
    context,
    title: title,
    body: message,
    intent: ToastIntent.success,
    duration: duration,
  );
}

/// Displays an error toast notification.
void showErrorToast(
  BuildContext context, {
  required String title,
  String? message,
  Duration duration = const Duration(seconds: 6),
}) {
  showFluentToast(
    context,
    title: title,
    body: message,
    intent: ToastIntent.error,
    duration: duration,
  );
}

/// Displays a warning toast notification.
void showWarningToast(
  BuildContext context, {
  required String title,
  String? message,
  Duration duration = const Duration(seconds: 5),
}) {
  showFluentToast(
    context,
    title: title,
    body: message,
    intent: ToastIntent.warning,
    duration: duration,
  );
}

/// Displays a progress toast notification.
///
/// Returns a [ToastController] that can be used to dismiss the toast
/// when the operation completes.
ToastController showProgressToast(
  BuildContext context, {
  required String title,
  String? message,
  double? progress,
  String? statusText,
}) {
  final controller = ToastController();
  showFluentToast(
    context,
    title: title,
    body: message,
    intent: ToastIntent.progress,
    progress: progress,
    statusText: statusText,
    controller: controller,
    dismissible: true,
  );
  return controller;
}

ToastIntent _severityToIntent(InfoBarSeverity severity) {
  switch (severity) {
    case InfoBarSeverity.success:
      return ToastIntent.success;
    case InfoBarSeverity.error:
      return ToastIntent.error;
    case InfoBarSeverity.warning:
      return ToastIntent.warning;
    case InfoBarSeverity.info:
      return ToastIntent.info;
  }
}
