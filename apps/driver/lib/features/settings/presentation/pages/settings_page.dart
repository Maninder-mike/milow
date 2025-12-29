import 'package:flutter/material.dart';
import 'dart:async';
import 'package:milow/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/auth_service.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/services/preferences_service.dart';

import 'package:milow/core/widgets/auth_wrapper.dart';
import 'package:milow/features/settings/presentation/pages/border_crossing_selector.dart';
import 'package:milow/features/settings/presentation/pages/about_page.dart';

import 'package:milow/core/services/trip_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _fullName;
  String? _email;
  String? _avatarUrl;

  UnitSystem _unitSystem = UnitSystem.metric;
  int _tripCount = 0;
  double _totalMiles = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPreferences();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Fetch fresh data from TripService
      final tripCount = await TripService.getTripsCount();
      final totalDistance = await TripService.getTotalDistance();

      // Calculate distance based on unit system preference
      final isMetric = _unitSystem == UnitSystem.metric;
      final displayDistance = isMetric
          ? totalDistance * 1.60934
          : totalDistance;

      if (mounted) {
        setState(() {
          _tripCount = tripCount;
          _totalMiles = displayDistance;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile stats: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final unitSystem = await PreferencesService.getUnitSystem();
    setState(() {
      _unitSystem = unitSystem;
    });
    // Reload stats after preference change to ensure correct units
    await _loadStats();
  }

  Future<void> _loadProfile() async {
    final cached = await ProfileRepository.getCachedFirst(refresh: false);
    setState(() {
      _fullName = cached?['full_name'] as String?;
      _email = cached?['email'] as String?;
      _avatarUrl = cached?['avatar_url'] as String?;
    });

    final fresh = await ProfileRepository.refresh();
    if (!mounted) return;
    if (fresh != null) {
      setState(() {
        _fullName = fresh['full_name'] as String?;
        _email = fresh['email'] as String?;
        _avatarUrl = fresh['avatar_url'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _fullName ?? AuthService.getCurrentUserName() ?? 'User';
    final userEmail = _email ?? AuthService.getCurrentUserEmail() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 20,
                      ),
                      onPressed: () => context.go('/dashboard'),
                    ),
                    Text(
                      'Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildProfileHeader(context, userName, userEmail, isDark),
              const SizedBox(height: 28),
              _buildAccountSection(context, textColor),
              const SizedBox(height: 24),
              _buildPreferencesSection(context, textColor),
              const SizedBox(height: 24),
              _buildDataSection(context, textColor),
              const SizedBox(height: 24),
              _buildSupportSection(context, textColor),
              const SizedBox(height: 24),
              _buildSignOutSection(context, textColor),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    String userName,
    String userEmail,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/edit-profile'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? NetworkImage(_avatarUrl!)
                      : null,
                  child: _avatarUrl == null || _avatarUrl!.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatBadge(
                            context,
                            _tripCount.toString(),
                            AppLocalizations.of(context)!.trips,
                          ),
                          const SizedBox(width: 8),
                          _buildStatBadge(
                            context,
                            _totalMiles >= 1000
                                ? '${(_totalMiles / 1000).toStringAsFixed(1)}K'
                                : _totalMiles.toStringAsFixed(0),
                            _unitSystem == UnitSystem.metric ? 'km' : 'mi',
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PRO',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label.toLowerCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, Color textColor) {
    return Column(
      children: [
        _buildSectionLabel('Account', textColor),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSolidCard(
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title:
                      AppLocalizations.of(context)?.editProfile ??
                      'Edit Profile',
                  iconColor: Theme.of(context).colorScheme.primary,
                  onTap: () => context.push('/edit-profile'),
                  textColor: textColor,
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.notifications_none_rounded,
                  title:
                      AppLocalizations.of(context)?.notifications ??
                      'Notifications',
                  iconColor: const Color(0xFFFF6B6B),
                  onTap: () => context.push('/notifications'),
                  textColor: textColor,
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title:
                      AppLocalizations.of(context)?.privacySecurity ??
                      'Privacy & Security',
                  iconColor: const Color(0xFF4ECDC4),
                  onTap: () => context.push('/privacy-security'),
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context, Color textColor) {
    return Column(
      children: [
        _buildSectionLabel('Preferences', textColor),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSolidCard(
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.palette_outlined,
                  title:
                      AppLocalizations.of(context)?.appearance ?? 'Appearance',
                  iconColor: const Color(0xFFFF8C42),
                  onTap: () => context.push('/appearance'),
                  textColor: textColor,
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.language_outlined,
                  title: AppLocalizations.of(context)?.language ?? 'Language',
                  iconColor: const Color(0xFF45B7D1),
                  onTap: () => context.push('/language'),
                  textColor: textColor,
                ),
                _buildDivider(),
                _buildUnitSystemItem(textColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context, Color textColor) {
    return Column(
      children: [
        _buildSectionLabel('Data', textColor),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSolidCard(
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.traffic_outlined,
                  title:
                      AppLocalizations.of(context)?.borderWaitTimes ??
                      'Border Wait Times',
                  iconColor: const Color(0xFFFECA57),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BorderCrossingSelector(),
                      ),
                    );
                  },
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context, Color textColor) {
    return Column(
      children: [
        _buildSectionLabel(AppLocalizations.of(context)!.support, textColor),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSolidCard(
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Send Feedback',
                  iconColor: Theme.of(context).colorScheme.primary,
                  onTap: () => context.push('/feedback'),
                  textColor: textColor,
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  iconColor: Theme.of(context).colorScheme.primary,
                  // TODO: Implement Help Center navigation
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help Center coming soon')),
                    );
                  },
                  textColor: textColor,
                ),

                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.info_outline,
                  title: 'About Milow',
                  iconColor: const Color(0xFFFF7675),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutPage()),
                  ),
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutSection(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildSolidCard(
        child: _buildMenuItem(
          icon: Icons.logout_rounded,
          title: AppLocalizations.of(context)?.signOut ?? 'Sign Out',
          iconColor: const Color(0xFFFF6B6B),
          isDestructive: true,
          onTap: () async {
            AuthWrapper.resetAuthenticationState();
            await AuthService.signOut();
            if (context.mounted) {
              context.go('/login');
            }
          },
          textColor: textColor,
          showChevron: false,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.5),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSolidCard({required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
    required Color textColor,
    bool isDestructive = false,
    bool showChevron = true,
  }) {
    final finalTextColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : textColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: finalTextColor,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outline,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildUnitSystemItem(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.straighten_outlined,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              AppLocalizations.of(context)?.unitSystem ?? 'Unit System',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentButton(
                  'Metric',
                  _unitSystem == UnitSystem.metric,
                  () async {
                    await PreferencesService.setUnitSystem(UnitSystem.metric);
                    setState(() => _unitSystem = UnitSystem.metric);
                  },
                ),
                _buildSegmentButton(
                  'Imperial',
                  _unitSystem == UnitSystem.imperial,
                  () async {
                    await PreferencesService.setUnitSystem(UnitSystem.imperial);
                    setState(() => _unitSystem = UnitSystem.imperial);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
