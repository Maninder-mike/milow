import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
            top: -80,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF007AFF).withValues(alpha: 0.25),
                    const Color(0xFF007AFF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D4AA).withValues(alpha: 0.2),
                    const Color(0xFF00D4AA).withValues(alpha: 0.0),
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
                              'Terms & Conditions',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Last updated: December 2025',
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
                        // App Icon
                        // Sizing it appropriately for desktop/admin view
                        const SizedBox(height: 24),
                        _buildSection(
                          title: '1. Acceptance of Terms',
                          content:
                              'By accessing and using the Milow Admin Dashboard, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by these terms, please do not use this service.',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: '2. Administrative Access',
                          content:
                              'This application is intended for authorized administrative personnel only. Unauthorized access is strictly prohibited and may result in legal action.\n\n• You must maintain strict confidentiality of all user data\n• You are responsible for all actions taken under your admin account\n• You agree to use the dashboard only for legitimate business purposes',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: '3. Data Privacy & Handling',
                          content:
                              'As an administrator, you have access to sensitive user data. You agree to:\n\n• Access user data only when necessary for support or operations\n• Never share or sell user data to third parties\n• Comply with all data protection regulations (GDPR, CCPA, etc.)',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: '4. Account Termination',
                          content:
                              'We reserve the right to revoke administrative access at any time without prior notice if you violate these Terms or engage in any activity that compromises the security or integrity of the platform.',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: '5. Disclaimer',
                          content:
                              'The Milow Admin Dashboard is provided "as is". We do not guarantee that the service will be uninterrupted or error-free.',
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: '6. Contact Support',
                          content:
                              'If you have any questions or require assistance, please contact the technical team at:\n\n📧 admin-support@milowapp.com',
                          cardColor: cardColor,
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
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
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
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF00D4AA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
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
