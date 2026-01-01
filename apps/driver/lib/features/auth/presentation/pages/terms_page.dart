import 'package:flutter/material.dart';
import 'package:milow/core/constants/design_tokens.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                          'Terms & Conditions',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Last updated: December 2025',
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
                    // App Icon
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(tokens.spacingL),
                        decoration: BoxDecoration(
                          color: tokens.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            tokens.shapeXL + tokens.spacingXS,
                          ),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Image.asset(
                          'assets/images/milow_icon.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.spacingXL),
                    _buildSection(
                      context: context,
                      title: '1. Acceptance of Terms',
                      content:
                          'By accessing and using the Milow application, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by these terms, please do not use this service.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: '2. Use of Service',
                      content:
                          'Milow is a trucking companion app designed to help truck drivers track their trips, fuel consumption, and expenses. You agree to use this service only for lawful purposes and in accordance with these Terms.\n\n• You must be at least 18 years old to use this service\n• You are responsible for maintaining the confidentiality of your account\n• You agree to provide accurate and complete information\n• You will not use the service for any illegal activities',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: '3. User Data',
                      content:
                          'We collect and store data that you provide to us, including:\n\n• Personal information (name, email)\n• Trip and route data\n• Fuel and expense records\n• Device information\n\nThis data is used to provide and improve our services. We do not sell your personal data to third parties.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: '4. Account Termination',
                      content:
                          'We reserve the right to terminate or suspend your account at any time without prior notice if you violate these Terms or engage in any activity that we deem harmful to other users or the service.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: '5. Disclaimer',
                      content:
                          'The Milow app is provided "as is" without warranties of any kind. We do not guarantee that the service will be uninterrupted, secure, or error-free. You use the service at your own risk.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: '6. Limitation of Liability',
                      content:
                          'In no event shall Milow or its developers be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use of the service.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: '7. Changes to Terms',
                      content:
                          'We reserve the right to modify these terms at any time. We will notify users of any material changes through the app or via email. Your continued use of the service after changes constitutes acceptance of the new terms.',
                    ),
                    SizedBox(height: tokens.spacingM),
                    _buildSection(
                      context: context,
                      title: '8. Contact Us',
                      content:
                          'If you have any questions about these Terms & Conditions, please contact us at:\n\n📧 support@milowapp.com',
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
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
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
        icon: Icon(icon, size: 18, color: colorScheme.onSurface),
        onPressed: onTap,
      ),
    );
  }
}
