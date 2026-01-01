import 'package:flutter/material.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:milow/core/services/theme_service.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:provider/provider.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final currentThemeMode = themeService.themeMode;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.appearance ?? 'Appearance',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: tokens.spacingM),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
              child: Text(
                'Theme',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            SizedBox(height: tokens.spacingM),
            Container(
              margin: EdgeInsets.symmetric(horizontal: tokens.spacingM),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(tokens.shapeL),
              ),
              child: Column(
                children: [
                  _buildThemeOption(
                    context,
                    'System Default',
                    'Follow system theme settings',
                    ThemeMode.system,
                    currentThemeMode,
                    themeService,
                  ),
                  _buildDivider(context),
                  _buildThemeOption(
                    context,
                    'Light',
                    'Light theme',
                    ThemeMode.light,
                    currentThemeMode,
                    themeService,
                  ),
                  _buildDivider(context),
                  _buildThemeOption(
                    context,
                    'Dark',
                    'Dark theme',
                    ThemeMode.dark,
                    currentThemeMode,
                    themeService,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    String subtitle,
    ThemeMode mode,
    ThemeMode currentMode,
    ThemeService themeService,
  ) {
    final isSelected = currentMode == mode;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return InkWell(
      onTap: () => themeService.setThemeMode(mode),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacingM),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.spacingXS),
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final tokens = context.tokens;
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
      indent: tokens.spacingM,
      endIndent: tokens.spacingM,
    );
  }
}
