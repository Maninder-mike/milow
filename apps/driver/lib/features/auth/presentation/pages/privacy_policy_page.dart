import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                          'Privacy Policy',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Your privacy matters to us',
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
                    _buildSection(
                      context: context,
                      title: 'Information We Collect',
                      icon: Icons.folder_outlined,
                      content:
                          'We collect information you provide directly to us:\n\n• Account information (name, email, password)\n• Profile information (profile picture, preferences)\n• Trip data (routes, distances, dates)\n• Fuel records (quantity, price, location)\n• Device information (device type, OS version)\n• Usage data (app interactions, feature usage)',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: 'How We Use Your Information',
                      icon: Icons.settings_outlined,
                      content:
                          'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Process and complete transactions\n• Send you technical notices and support messages\n• Respond to your comments and questions\n• Generate analytics and insights for your trips\n• Detect, investigate, and prevent fraudulent activities',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: 'Data Storage & Security',
                      icon: Icons.lock_outline,
                      content:
                          'Your data is stored securely using industry-standard encryption:\n\n🔒 All data is encrypted in transit (TLS/SSL)\n🔒 Data at rest is encrypted using AES-256\n🔒 We use Supabase for secure cloud storage\n🔒 Regular security audits are performed\n🔒 Access to data is strictly controlled',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: 'Data Sharing',
                      icon: Icons.share_outlined,
                      content:
                          'We do NOT sell your personal data. We may share information only:\n\n• With your consent\n• To comply with legal obligations\n• To protect our rights and safety\n• With service providers who assist our operations\n• In aggregated, anonymized form for analytics',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: 'Your Rights',
                      icon: Icons.verified_user_outlined,
                      content:
                          'You have the right to:\n\n✓ Access your personal data\n✓ Correct inaccurate data\n✓ Delete your account and data\n✓ Export your data\n✓ Opt out of marketing communications\n✓ Withdraw consent at any time',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: 'Data Retention',
                      icon: Icons.access_time,
                      content:
                          'We retain your data for as long as your account is active or as needed to provide services. If you delete your account, we will delete your personal data within 30 days, except where retention is required by law.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: 'Children\'s Privacy',
                      icon: Icons.child_care,
                      content:
                          'Milow is not intended for children under 18. We do not knowingly collect personal information from children. If we learn that we have collected data from a child, we will delete it promptly.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context: context,
                      title: 'Contact Us',
                      icon: Icons.email_outlined,
                      content:
                          'If you have questions about this Privacy Policy or your data, please contact us:\n\n📧 privacy@milowapp.com\n📍 Your data protection inquiries will be handled within 30 days.',
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // Last updated
                    Center(
                      child: Text(
                        'Last updated: December 2025',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF667085),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
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
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: onTap,
      ),
    );
  }
}
