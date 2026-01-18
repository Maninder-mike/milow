import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_elevation.dart';

/// Toast intent types following Fluent 2 design system.
/// Each intent has semantic styling, icons, and aria behavior.
enum ToastIntent {
  /// Success confirmation toast - green checkmark
  success,

  /// Error state toast - red error icon
  error,

  /// Warning state toast - amber warning icon
  warning,

  /// Informational toast - blue info icon
  info,

  /// Progress toast - shows loading spinner
  progress,
}

/// Configuration for a toast action button.
class ToastAction {
  final String label;
  final VoidCallback onPressed;

  const ToastAction({required this.label, required this.onPressed});
}

/// A toast controller to manage toast lifecycle externally.
/// Useful for progress toasts that need to be dismissed on completion.
class ToastController {
  VoidCallback? _dismiss;

  void dismiss() {
    _dismiss?.call();
  }

  void _attach(VoidCallback dismiss) {
    _dismiss = dismiss;
  }
}

/// Displays a Fluent 2 styled toast notification.
///
/// Toast types:
/// - **Confirmation**: Shown as a result of user action (success, error, warning, info)
/// - **Progress**: Shown during async operations
/// - **Communication**: External events (mentions, reminders, system updates)
///
/// Layout:
/// - Toasts appear in the bottom-right corner, 16px from edges
/// - Stack up to 4 toasts with 16px spacing between them
/// - New toasts push older ones up
void showFluentToast(
  BuildContext context, {
  required String title,
  String? body,
  ToastIntent intent = ToastIntent.info,
  Duration duration = const Duration(seconds: 7),
  ToastAction? action,
  ToastController? controller,
  bool dismissible = true,
  double? progress,
  String? statusText,
}) {
  final overlay = Overlay.of(context);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _FluentToast(
      title: title,
      body: body,
      intent: intent,
      duration: duration,
      action: action,
      dismissible: dismissible,
      progress: progress,
      statusText: statusText,
      onDismiss: () => entry.remove(),
      controller: controller,
    ),
  );

  overlay.insert(entry);
}

/// Legacy function for backwards compatibility.
/// @deprecated Use [showFluentToast] instead.
void showToast(
  BuildContext context, {
  required String title,
  required String message,
  ToastType type = ToastType.info,
  Duration duration = const Duration(seconds: 4),
}) {
  showFluentToast(
    context,
    title: title,
    body: message,
    intent: _toastTypeToIntent(type),
    duration: duration,
  );
}

/// Legacy toast type enum for backwards compatibility.
/// @deprecated Use [ToastIntent] instead.
enum ToastType { success, error, warning, info }

ToastIntent _toastTypeToIntent(ToastType type) {
  switch (type) {
    case ToastType.success:
      return ToastIntent.success;
    case ToastType.error:
      return ToastIntent.error;
    case ToastType.warning:
      return ToastIntent.warning;
    case ToastType.info:
      return ToastIntent.info;
  }
}

class _FluentToast extends StatefulWidget {
  final String title;
  final String? body;
  final ToastIntent intent;
  final Duration duration;
  final ToastAction? action;
  final bool dismissible;
  final double? progress;
  final String? statusText;
  final VoidCallback onDismiss;
  final ToastController? controller;

  const _FluentToast({
    required this.title,
    this.body,
    required this.intent,
    required this.duration,
    this.action,
    this.dismissible = true,
    this.progress,
    this.statusText,
    required this.onDismiss,
    this.controller,
  });

  @override
  State<_FluentToast> createState() => _FluentToastState();
}

class _FluentToastState extends State<_FluentToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  bool _isPaused = false;
  Duration _remainingDuration = Duration.zero;
  DateTime? _pauseTime;

  @override
  void initState() {
    super.initState();

    _remainingDuration = widget.duration;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Fluent 2 uses ease-out for enter animations
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Attach controller for external dismissal
    widget.controller?._attach(_dismiss);

    // Auto-dismiss for non-progress toasts
    if (widget.intent != ToastIntent.progress) {
      _startDismissTimer();
    }
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_remainingDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _pauseTimer() {
    if (_dismissTimer?.isActive ?? false) {
      _dismissTimer?.cancel();
      _pauseTime = DateTime.now();
      _isPaused = true;
    }
  }

  void _resumeTimer() {
    if (_isPaused && _pauseTime != null) {
      final elapsed = DateTime.now().difference(_pauseTime!);
      _remainingDuration = _remainingDuration - elapsed;
      if (_remainingDuration > Duration.zero) {
        _startDismissTimer();
      } else {
        _dismiss();
      }
      _isPaused = false;
    }
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Use solid opaque background for toasts
    final backgroundColor = isLight
        ? theme.resources.solidBackgroundFillColorSecondary
        : theme.resources.solidBackgroundFillColorBase;

    final borderColor = theme.resources.cardStrokeColorDefault;

    return Positioned(
      right: 16,
      bottom: 56, // Above status bar
      child: MouseRegion(
        onEnter: (_) => _pauseTimer(),
        onExit: (_) => _resumeTimer(),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 360,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
                boxShadow: AppElevation.shadow8(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main content row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status icon
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _buildStatusIcon(),
                        ),
                        const SizedBox(width: 12),

                        // Title, body, and status text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title
                              Text(
                                widget.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.resources.textFillColorPrimary,
                                ),
                              ),

                              // Body (optional)
                              if (widget.body != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.body!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color:
                                        theme.resources.textFillColorSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              // Status text for progress toasts
                              if (widget.statusText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.statusText!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color:
                                        theme.resources.textFillColorSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Close button (if dismissible)
                        if (widget.dismissible)
                          GestureDetector(
                            onTap: _dismiss,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  FluentIcons.dismiss_20_regular,
                                  size: 16,
                                  color: theme.resources.textFillColorSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Progress bar (for progress toasts)
                  if (widget.intent == ToastIntent.progress) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        height: 4,
                        child: ProgressBar(
                          value: widget.progress,
                          strokeWidth: 4,
                          backgroundColor: isLight
                              ? theme.resources.controlStrongFillColorDefault
                                    .withValues(alpha: 0.1)
                              : theme.resources.controlStrongFillColorDefault
                                    .withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ],

                  // Action button (optional)
                  if (widget.action != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(52, 0, 16, 12),
                      child: HyperlinkButton(
                        onPressed: () {
                          widget.action!.onPressed();
                          _dismiss();
                        },
                        child: Text(
                          widget.action!.label,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (widget.intent) {
      case ToastIntent.success:
        return Icon(
          FluentIcons.checkmark_circle_20_filled,
          size: 20,
          color: _getIntentColor(),
        );
      case ToastIntent.error:
        return Icon(
          FluentIcons.error_circle_20_filled,
          size: 20,
          color: _getIntentColor(),
        );
      case ToastIntent.warning:
        return Icon(
          FluentIcons.warning_20_filled,
          size: 20,
          color: _getIntentColor(),
        );
      case ToastIntent.info:
        return Icon(
          FluentIcons.info_20_filled,
          size: 20,
          color: _getIntentColor(),
        );
      case ToastIntent.progress:
        return SizedBox(
          width: 20,
          height: 20,
          child: ProgressRing(
            strokeWidth: 2.5,
            activeColor: FluentTheme.of(context).accentColor,
          ),
        );
    }
  }

  Color _getIntentColor() {
    switch (widget.intent) {
      case ToastIntent.success:
        return const Color(0xFF107C10); // Fluent Green
      case ToastIntent.error:
        return const Color(0xFFC42B1C); // Fluent Red
      case ToastIntent.warning:
        return const Color(0xFFF7630C); // Fluent Orange
      case ToastIntent.info:
        return const Color(0xFF0078D4); // Fluent Blue
      case ToastIntent.progress:
        return FluentTheme.of(context).accentColor;
    }
  }
}
