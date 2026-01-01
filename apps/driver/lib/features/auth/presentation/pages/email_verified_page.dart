import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milow/core/constants/design_tokens.dart';

class EmailVerifiedPage extends StatelessWidget {
  const EmailVerifiedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacingL,
              vertical: tokens.spacingXL,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: EdgeInsets.all(tokens.spacingXL),
                decoration: BoxDecoration(
                  color: tokens.surfaceContainer,
                  borderRadius: BorderRadius.circular(
                    tokens.shapeL + tokens.spacingXS,
                  ),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(tokens.spacingL),
                      decoration: BoxDecoration(
                        color: tokens.scaffoldAltBackground,
                        borderRadius: BorderRadius.circular(
                          tokens.shapeXL + tokens.spacingXS,
                        ),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Icon(
                        Icons.verified_outlined,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: tokens.spacingXL),
                    Text(
                      'Email Verified!',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    SizedBox(height: tokens.spacingM),
                    Text(
                      'Your account email has been successfully confirmed. You now have full access to Milow features.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                        color: tokens.textSecondary,
                      ),
                    ),
                    SizedBox(height: tokens.spacingL),
                    Container(
                      padding: EdgeInsets.all(tokens.spacingM),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tokens.shapeL),
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          SizedBox(width: tokens.spacingM),
                          Expanded(
                            child: Text(
                              'Security tip: Keep your email updated to ensure uninterrupted access.',
                              style: textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.spacingXL),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go('/dashboard'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.shapeL),
                          ),
                        ),
                        child: Text(
                          'Continue to Dashboard',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spacingM),
                    TextButton(
                      onPressed: () => context.go('/settings'),
                      child: Text(
                        'Manage Profile',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
