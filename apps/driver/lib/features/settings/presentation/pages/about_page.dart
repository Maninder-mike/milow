import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:milow/core/constants/design_tokens.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';
  String _appName = 'Milow';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
      _appName = info.appName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      appBar: AppBar(
        backgroundColor: tokens.scaffoldAltBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: tokens.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About',
          style: textTheme.titleMedium?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingL,
          vertical: tokens.spacingXL + tokens.spacingM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo Section
            Center(
              child: Container(
                width: 120,
                height: 120,
                padding: EdgeInsets.all(tokens.spacingXS),
                decoration: BoxDecoration(
                  color: tokens.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/milow_icon_beta.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.spacingL),

            // App Name & Version
            Text(
              _appName,
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
            ),
            SizedBox(height: tokens.spacingS),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacingM,
                vertical: tokens.spacingS,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  tokens.shapeL + tokens.spacingXS,
                ),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Version $_version ($_buildNumber)',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: tokens.spacingXL + tokens.spacingM),

            // Description Card
            Container(
              padding: EdgeInsets.all(tokens.spacingL),
              decoration: BoxDecoration(
                color: tokens.surfaceContainer,
                borderRadius: BorderRadius.circular(
                  tokens.shapeL + tokens.spacingXS,
                ),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                'Milow is designed to help truck drivers manage their trips, track fuel expenses, and optimize their journey. With powerful tools and insights, we keep you moving forward.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            SizedBox(height: tokens.spacingL),

            // Info Rows
            _buildInfoRow(context, 'Developer', 'Maninder Singh', Icons.code),
            SizedBox(height: tokens.spacingM),
            _buildInfoRow(
              context,
              'Website',
              'www.maninder.co.in',
              Icons.language,
            ),
            SizedBox(height: tokens.spacingM),
            _buildInfoRow(
              context,
              'Contact',
              'info@maninder.co.in',
              Icons.mail_outline,
            ),

            SizedBox(height: tokens.spacingXL * 2 + tokens.spacingM),

            Text(
              '© ${DateTime.now().year} Maninder Corp. All rights reserved.',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeL + tokens.spacingXS),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(tokens.spacingS),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(tokens.shapeS + 2),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          SizedBox(width: tokens.spacingM),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
