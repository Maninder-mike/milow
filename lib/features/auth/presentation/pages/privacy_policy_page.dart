import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF0F4F8);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -60,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D4AA).withValues(alpha: 0.25),
                    const Color(0xFF00D4AA).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF007AFF).withValues(alpha: 0.2),
                    const Color(0xFF007AFF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildGlassButton(
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
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Your privacy matters to us',
                              style: GoogleFonts.inter(
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
                          title: 'Information We Collect',
                          icon: Icons.folder_outlined,
                          content:
                              'We collect information you provide directly to us:\n\n• Account information (name, email, password)\n• Profile information (profile picture, preferences)\n• Trip data (routes, distances, dates)\n• Fuel records (quantity, price, location)\n• Device information (device type, OS version)\n• Usage data (app interactions, feature usage)',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'How We Use Your Information',
                          icon: Icons.settings_outlined,
                          content:
                              'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Process and complete transactions\n• Send you technical notices and support messages\n• Respond to your comments and questions\n• Generate analytics and insights for your trips\n• Detect, investigate, and prevent fraudulent activities',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'Data Storage & Security',
                          icon: Icons.lock_outline,
                          content:
                              'Your data is stored securely using industry-standard encryption:\n\n🔒 All data is encrypted in transit (TLS/SSL)\n🔒 Data at rest is encrypted using AES-256\n🔒 We use Supabase for secure cloud storage\n🔒 Regular security audits are performed\n🔒 Access to data is strictly controlled',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'Data Sharing',
                          icon: Icons.share_outlined,
                          content:
                              'We do NOT sell your personal data. We may share information only:\n\n• With your consent\n• To comply with legal obligations\n• To protect our rights and safety\n• With service providers who assist our operations\n• In aggregated, anonymized form for analytics',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'Your Rights',
                          icon: Icons.verified_user_outlined,
                          content:
                              'You have the right to:\n\n✓ Access your personal data\n✓ Correct inaccurate data\n✓ Delete your account and data\n✓ Export your data\n✓ Opt out of marketing communications\n✓ Withdraw consent at any time',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'Data Retention',
                          icon: Icons.access_time,
                          content:
                              'We retain your data for as long as your account is active or as needed to provide services. If you delete your account, we will delete your personal data within 30 days, except where retention is required by law.',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'Children\'s Privacy',
                          icon: Icons.child_care,
                          content:
                              'Milow is not intended for children under 18. We do not knowingly collect personal information from children. If we learn that we have collected data from a child, we will delete it promptly.',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'Contact Us',
                          icon: Icons.email_outlined,
                          content:
                              'If you have questions about this Privacy Policy or your data, please contact us:\n\n📧 privacy@milowapp.com\n📍 Your data protection inquiries will be handled within 30 days.',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),

                        // Last updated
                        Center(
                          child: Text(
                            'Last updated: December 2025',
                            style: GoogleFonts.inter(
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
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
    required Color cardColor,
    required Color textColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF007AFF).withValues(alpha: 0.15),
                      const Color(0xFF00D4AA).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF007AFF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF101828),
            ),
          ),
        ),
      ),
    );
  }
}
