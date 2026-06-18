import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/widgets/m3_spring_button.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return M3SpringButton(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.tokens.spacingS),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(context.tokens.shapeM),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            SizedBox(height: context.tokens.spacingXS),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
