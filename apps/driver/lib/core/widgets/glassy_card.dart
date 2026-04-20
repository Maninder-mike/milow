import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

/// A premium M3 glassmorphic card widget
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
    final tokens = context.tokens;
    
    final cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: tokens.glassBlur, sigmaY: tokens.glassBlur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: tokens.glassOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: tokens.glassBorderOpacity),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
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
