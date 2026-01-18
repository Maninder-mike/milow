import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/theme/m3_expressive_motion.dart';

/// Reusable error state widget with M3 Expressive entrance animation
///
/// Shows an error icon, message, and optional retry button.
/// Use this instead of inline error handling for consistent UX.
///
/// Usage:
/// ```dart
/// ErrorStateWidget(
///   message: 'Failed to load data',
///   onRetry: () => ref.refresh(myProvider),
/// )
/// ```
class ErrorStateWidget extends StatelessWidget {
  /// The error message to display
  final String message;

  /// Optional callback when retry button is pressed
  final VoidCallback? onRetry;

  /// Custom icon (defaults to error_outline)
  final IconData icon;

  /// Custom retry button text
  final String retryText;

  /// Whether to show the error in a compact form
  final bool compact;

  const ErrorStateWidget({
    required this.message,
    super.key,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.retryText = 'Try Again',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    if (compact) {
      return M3ExpressiveEntrance(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colorScheme.error, size: 20),
              SizedBox(width: tokens.spacingS),
              Flexible(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(width: tokens.spacingS),
                TextButton(onPressed: onRetry, child: Text(retryText)),
              ],
            ],
          ),
        ),
      );
    }

    return M3ExpressiveEntrance(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(tokens.spacingL),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: colorScheme.error),
              ),
              SizedBox(height: tokens.spacingL),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: tokens.spacingL),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(retryText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable empty state widget with M3 Expressive entrance animation
///
/// Shows an illustration/icon, title, subtitle, and optional action button.
/// Use this for empty lists, search results, etc.
///
/// Usage:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.inbox_rounded,
///   title: 'No messages yet',
///   subtitle: 'Start a conversation with your dispatcher',
///   actionText: 'New Message',
///   onAction: () => context.push('/inbox/new'),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// Icon to display
  final IconData icon;

  /// Title text
  final String title;

  /// Subtitle/description text
  final String? subtitle;

  /// Optional action button text
  final String? actionText;

  /// Callback when action button is pressed
  final VoidCallback? onAction;

  /// Whether to show in compact form
  final bool compact;

  const EmptyStateWidget({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    if (compact) {
      return M3ExpressiveEntrance(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: colorScheme.onSurfaceVariant),
              SizedBox(height: tokens.spacingS),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return M3ExpressiveEntrance(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(tokens.spacingL),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spacingL),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
              ),
              if (subtitle != null) ...[
                SizedBox(height: tokens.spacingS),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionText != null && onAction != null) ...[
                SizedBox(height: tokens.spacingL),
                FilledButton(onPressed: onAction, child: Text(actionText!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
