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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: tokens.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/milow_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacingXL),

            // App Name & Version
            Text(
              _appName,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Version $_version ($_buildNumber)',
              style: textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: tokens.spacingXL + tokens.spacingM),

            // Description
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacingL),
              child: Text(
                'Milow is designed to help truck drivers manage their trips, track fuel expenses, and optimize their journey. With powerful tools and insights, we keep you moving forward.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: tokens.spacingXL * 1.5),

            // Info Section
            _buildSectionHeader('Application Info'),
            _buildInfoRow(
              context,
              'Developer',
              'Maninder Singh',
              Icons.code_rounded,
            ),
            _buildInfoRow(
              context,
              'Website',
              'maninder.co.in',
              Icons.language_rounded,
            ),
            _buildInfoRow(
              context,
              'Contact Support',
              'info@maninder.co.in',
              Icons.support_agent_rounded,
            ),
            _buildInfoRow(
              context,
              'Privacy Policy',
              'View Details',
              Icons.privacy_tip_outlined,
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

  Widget _buildSectionHeader(String title) {
    final tokens = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacingM, left: 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
          ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: tokens.inputBackground,
        borderRadius: BorderRadius.circular(tokens.shapeS),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          SizedBox(width: tokens.spacingM),
          Text(
            label,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
