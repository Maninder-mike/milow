import 'package:flutter/material.dart';

/// A reusable iOS 26-style glassy/frosted card widget
class GlassyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? accentColor;
  final VoidCallback? onTap;

  const GlassyCard({
    required this.child,
    super.key,
    this.padding,
    this.borderRadius = 20,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// A standard background for pages (no gradients)
class GlassyBackground extends StatelessWidget {
  final Widget child;

  const GlassyBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
