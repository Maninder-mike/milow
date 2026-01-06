import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFF0F4F8);
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return ScaffoldPage(
      content: Container(
        color: backgroundColor,
        child: Stack(
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
                          icon: FluentIcons.chevron_left_24_regular,
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
                                'Admin Data Protection Protocol',
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
                            title: 'Internal Data Policy',
                            icon: FluentIcons.folder_24_regular,
                            content:
                                'This privacy policy outlines the handling of data within the Milow Admin Dashboard. All administrators are bound by strict non-disclosure agreements regarding user data.',
                            cardColor: cardColor,
                            textColor: textColor,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildSection(
                            title: 'Access Control',
                            icon: FluentIcons.lock_closed_24_regular,
                            content:
                                'Access to user data is logged and audited. Administrators should only access personal identifying information (PII) when strictly necessary for support tickets or system maintenance.',
                            cardColor: cardColor,
                            textColor: textColor,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildSection(
                            title: 'Data Security',
                            icon: FluentIcons.shield_24_regular,
                            content:
                                'Ensure that you:\n\n• Use strong, unique passwords for your admin account\n• Enable 2FA where available\n• Monitor for suspicious activity\n• Report potential breaches immediately',
                            cardColor: cardColor,
                            textColor: textColor,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildSection(
                            title: 'Confidentiality',
                            icon: FluentIcons.shield_checkmark_24_regular,
                            content:
                                'User data is confidential. Sharing screenshots or raw data outside of authorized channels is strictly prohibited.',
                            cardColor: cardColor,
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
          ],
        ),
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
