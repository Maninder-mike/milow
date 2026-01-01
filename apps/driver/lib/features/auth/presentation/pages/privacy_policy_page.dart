import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.scaffoldAltBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(tokens.spacingM),
              child: Row(
                children: [
                  _buildNavButton(
                    context: context,
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.pop(context),
                  ),
                  SizedBox(width: tokens.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Your privacy matters to us',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacingM,
                  tokens.spacingS,
                  tokens.spacingM,
                  tokens.spacingL,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      context: context,
                      title: 'Information We Collect',
                      icon: Icons.folder_outlined,
                      content:
                          'We collect information you provide directly to us:\n\n• Account information (name, email, password)\n• Profile information (profile picture, preferences)\n• Trip data (routes, distances, dates)\n• Fuel records (quantity, price, location)\n• Device information (device type, OS version)\n• Usage data (app interactions, feature usage)',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: 'How We Use Your Information',
                      icon: Icons.settings_outlined,
                      content:
                          'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Process and complete transactions\n• Send you technical notices and support messages\n• Respond to your comments and questions\n• Generate analytics and insights for your trips\n• Detect, investigate, and prevent fraudulent activities',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: 'Data Storage & Security',
                      icon: Icons.lock_outline,
                      content:
                          'Your data is stored securely using industry-standard encryption:\n\n🔒 All data is encrypted in transit (TLS/SSL)\n🔒 Data at rest is encrypted using AES-256\n🔒 We use Supabase for secure cloud storage\n🔒 Regular security audits are performed\n🔒 Access to data is strictly controlled',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: 'Data Sharing',
                      icon: Icons.share_outlined,
                      content:
                          'We do NOT sell your personal data. We may share information only:\n\n• With your consent\n• To comply with legal obligations\n• To protect our rights and safety\n• With service providers who assist our operations\n• In aggregated, anonymized form for analytics',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: 'Your Rights',
                      icon: Icons.verified_user_outlined,
                      content:
                          'You have the right to:\n\n✓ Access your personal data\n✓ Correct inaccurate data\n✓ Delete your account and data\n✓ Export your data\n✓ Opt out of marketing communications\n✓ Withdraw consent at any time',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: 'Data Retention',
                      icon: Icons.access_time,
                      content:
                          'We retain your data for as long as your account is active or as needed to provide services. If you delete your account, we will delete your personal data within 30 days, except where retention is required by law.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: 'Children\'s Privacy',
                      icon: Icons.child_care,
                      content:
                          'Milow is not intended for children under 18. We do not knowingly collect personal information from children. If we learn that we have collected data from a child, we will delete it promptly.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: 'Contact Us',
                      icon: Icons.email_outlined,
                      content:
                          'If you have questions about this Privacy Policy or your data, please contact us:\n\n📧 privacy@milowapp.com\n📍 Your data protection inquiries will be handled within 30 days.',
                    ),
                    SizedBox(height: tokens.spacingM),

                    // Last updated
                    Center(
                      child: Text(
                        'Last updated: December 2025',
                        style: textTheme.labelSmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String content,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(tokens.spacingS),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(tokens.shapeS + 2),
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
              SizedBox(width: tokens.spacingM),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacingM),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.shapeM),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        onPressed: onTap,
      ),
    );
  }
}
