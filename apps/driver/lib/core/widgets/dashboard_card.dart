import 'package:flutter/material.dart';

import 'package:milow/core/constants/design_tokens.dart';

class DashboardCard extends StatelessWidget {
  final String value;
  final String title;
  final IconData icon;
  final Color color;
  final String? trend;

  const DashboardCard({
    required this.value,
    required this.title,
    required this.icon,
    required this.color,
    super.key,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$title: $value${trend != null ? ', trend $trend' : ''}',
      child: Container(
        padding: EdgeInsets.all(tokens.spacingM),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(tokens.radiusXL),
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(tokens.radiusM),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(tokens.radiusL),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            SizedBox(height: tokens.spacingM - 2),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: tokens.spacingXS),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (trend != null) ...[
              SizedBox(height: tokens.spacingS),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacingS + 2,
                  vertical: tokens.spacingXS + 1,
                ),
                decoration: BoxDecoration(
                  color:
                      (trend!.startsWith('+') ? tokens.success : tokens.error)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.radiusS + 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trend!.startsWith('+')
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                      color: trend!.startsWith('+')
                          ? tokens.success
                          : tokens.error,
                    ),
                    SizedBox(width: tokens.spacingXS - 1),
                    Text(
                      trend!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: trend!.startsWith('+')
                            ? tokens.success
                            : tokens.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
