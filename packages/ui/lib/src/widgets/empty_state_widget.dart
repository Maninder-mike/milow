import 'package:flutter/material.dart';

/// A reusable empty state widget for clean data presentation when lists or pages are empty.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.iconSize = 64,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  primaryActionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
