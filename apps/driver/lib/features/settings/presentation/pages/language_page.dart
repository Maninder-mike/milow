import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:milow/core/services/locale_service.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:milow/core/constants/design_tokens.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  final List<Map<String, dynamic>> _languages = [
    {
      'code': 'en',
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
      'supported': true,
    },
    {
      'code': 'pa',
      'name': 'Punjabi (Gurmukhi)',
      'nativeName': 'ਪੰਜਾਬੀ',
      'flag': '🇮🇳',
      'supported': true,
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'nativeName': 'हिन्दी',
      'flag': '🇮🇳',
      'supported': true,
    },
    {
      'code': 'ur',
      'name': 'Urdu',
      'nativeName': 'اردو',
      'flag': '🇵🇰',
      'supported': true,
    },
  ];

  Future<void> _setLanguage(String languageCode, bool isSupported) async {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (!isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This language is coming soon!',
            style: textTheme.bodyMedium,
          ),
          backgroundColor: tokens.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.shapeS),
          ),
        ),
      );
      return;
    }

    await localeService.setLocaleByCode(languageCode);

    if (!mounted) return;

    final language = _languages.firstWhere((l) => l['code'] == languageCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Language changed to ${language['name']}',
          style: textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: tokens.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shapeS),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        backgroundColor: tokens.scaffoldAltBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)?.language ?? 'Language',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<LocaleService>(
        builder: (context, localeService, child) {
          final selectedLanguage = localeService.locale.languageCode;

          return ListView(
            padding: EdgeInsets.all(tokens.spacingM),
            children: [
              Text(
                'Select your preferred language',
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              SizedBox(height: tokens.spacingM),
              Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceContainer,
                  borderRadius: BorderRadius.circular(tokens.shapeL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: _languages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final language = entry.value;
                    final isSelected = selectedLanguage == language['code'];
                    final isLast = index == _languages.length - 1;
                    final isSupported = language['supported'] as bool;

                    return Column(
                      children: [
                        InkWell(
                          onTap: () =>
                              _setLanguage(language['code']!, isSupported),
                          borderRadius: BorderRadius.vertical(
                            top: index == 0
                                ? Radius.circular(tokens.shapeL)
                                : Radius.zero,
                            bottom: isLast
                                ? Radius.circular(tokens.shapeL)
                                : Radius.zero,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacingM,
                              vertical: tokens.spacingM - 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  language['flag']!,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                SizedBox(width: tokens.spacingM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            language['name']!,
                                            style: textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: isSupported
                                                      ? tokens.textPrimary
                                                      : tokens.textSecondary,
                                                ),
                                          ),
                                          if (!isSupported) ...[
                                            SizedBox(width: tokens.spacingS),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: tokens.warning
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      tokens.shapeXS,
                                                    ),
                                              ),
                                              child: Text(
                                                'Soon',
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: tokens.warning,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        language['nativeName']!,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: EdgeInsets.all(
                                      tokens.spacingXS - 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: tokens.subtleBorderColor,
                            indent: 56,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: tokens.spacingL),
              Container(
                padding: EdgeInsets.all(tokens.spacingM),
                decoration: BoxDecoration(
                  color: tokens.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(tokens.shapeM),
                  border: Border.all(
                    color: tokens.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 24,
                      color: tokens.success,
                    ),
                    SizedBox(width: tokens.spacingM),
                    Expanded(
                      child: Text(
                        'All languages are fully supported!',
                        style: textTheme.bodyMedium?.copyWith(
                          color: tokens.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
