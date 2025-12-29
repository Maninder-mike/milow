import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildNavButton(
                    context: context,
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.pop(context),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms & Conditions',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Last updated: December 2025',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF667085),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/milow_icon.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSection(
                      context: context,
                      title: '1. Acceptance of Terms',
                      content:
                          'By accessing and using the Milow application, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by these terms, please do not use this service.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: '2. Use of Service',
                      content:
                          'Milow is a trucking companion app designed to help truck drivers track their trips, fuel consumption, and expenses. You agree to use this service only for lawful purposes and in accordance with these Terms.\n\n• You must be at least 18 years old to use this service\n• You are responsible for maintaining the confidentiality of your account\n• You agree to provide accurate and complete information\n• You will not use the service for any illegal activities',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: '3. User Data',
                      content:
                          'We collect and store data that you provide to us, including:\n\n• Personal information (name, email)\n• Trip and route data\n• Fuel and expense records\n• Device information\n\nThis data is used to provide and improve our services. We do not sell your personal data to third parties.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: '4. Account Termination',
                      content:
                          'We reserve the right to terminate or suspend your account at any time without prior notice if you violate these Terms or engage in any activity that we deem harmful to other users or the service.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: '5. Disclaimer',
                      content:
                          'The Milow app is provided "as is" without warranties of any kind. We do not guarantee that the service will be uninterrupted, secure, or error-free. You use the service at your own risk.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: '6. Limitation of Liability',
                      content:
                          'In no event shall Milow or its developers be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use of the service.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: '7. Changes to Terms',
                      content:
                          'We reserve the right to modify these terms at any time. We will notify users of any material changes through the app or via email. Your continued use of the service after changes constitutes acceptance of the new terms.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: '8. Contact Us',
                      content:
                          'If you have any questions about these Terms & Conditions, please contact us at:\n\n📧 support@milowapp.com',
                      textColor: textColor,
                      isDark: isDark,
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
    required Color textColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.outfit(
              fontSize: 14,
              height: 1.6,
              color: const Color(0xFF667085),
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
    required bool isDark,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: onTap,
      ),
    );
  }
}
