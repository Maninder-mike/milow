import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/auth_service.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/services/preferences_service.dart';
import 'package:milow/core/services/version_checker_service.dart';
import 'package:milow/core/utils/app_dialogs.dart';
import 'package:milow/core/widgets/auth_wrapper.dart';
import 'package:milow/features/settings/presentation/pages/border_crossing_selector.dart';

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
  bool _loading = true;
  bool _showWeather = true;
  bool _showTruckingNews = false;
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

      if (mounted) {
        setState(() {
          _tripCount = tripCount;
          _totalMiles = totalDistance;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadPreferences() async {
    final showWeather = await PreferencesService.getShowWeather();
    final showTruckingNews = await PreferencesService.getShowTruckingNews();
    final unitSystem = await PreferencesService.getUnitSystem();
    setState(() {
      _showWeather = showWeather;
      _showTruckingNews = showTruckingNews;
      _unitSystem = unitSystem;
    });
  }

  Future<void> _loadProfile() async {
    final cached = await ProfileRepository.getCachedFirst(refresh: false);
    setState(() {
      _fullName = cached?['full_name'] as String?;
      _email = cached?['email'] as String?;
      _avatarUrl = cached?['avatar_url'] as String?;
      _loading = false;
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f0f23),
                ]
              : [
                  const Color(0xFFe8f4f8),
                  const Color(0xFFfce4ec),
                  const Color(0xFFe8f5e9),
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildProfileHeader(context, userName, userEmail, isDark),
              const SizedBox(height: 28),
              _buildAccountSection(context, isDark),
              const SizedBox(height: 24),
              _buildPreferencesSection(context, isDark),
              const SizedBox(height: 24),
              _buildDataSection(context, isDark),
              const SizedBox(height: 24),
              _buildSupportSection(context, isDark),
              const SizedBox(height: 24),
              _buildSignOutSection(context, isDark),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.7),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Futuristic accent line
                Positioned(
                  top: 0,
                  left: 40,
                  right: 40,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF6C5CE7).withValues(alpha: 0.8),
                          const Color(0xFF00D9FF).withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Minimal futuristic avatar
                      _buildFuturisticAvatar(context, userName, isDark),
                      const SizedBox(width: 16),
                      // User info - minimal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF101828),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : const Color(0xFF667085),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // Minimal stats row
                            Row(
                              children: [
                                _buildMinimalStat(
                                  _tripCount.toString(),
                                  AppLocalizations.of(
                                    context,
                                  )!.trips.toLowerCase(),
                                  isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildMinimalStat(
                                  _totalMiles >= 1000
                                      ? '${(_totalMiles / 1000).toStringAsFixed(1)}K'
                                      : _totalMiles.toStringAsFixed(0),
                                  AppLocalizations.of(
                                    context,
                                  )!.totalDrivenMiles,
                                  isDark,
                                ),
                                const SizedBox(width: 16),
                                _buildProBadge(isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit button - minimal
                      GestureDetector(
                        onTap: () => context.push('/edit-profile'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : const Color(0xFF667085),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFuturisticAvatar(
    BuildContext context,
    String userName,
    bool isDark,
  ) {
    if (_loading) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3.0,
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/edit-profile'),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C5CE7), Color(0xFF00D9FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF1a1a2e) : Colors.white,
          ),
          child: _avatarUrl != null && _avatarUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    _avatarUrl!,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                  ),
                )
              : Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF00D9FF)],
                    ).createShader(bounds),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMinimalStat(String value, String label, bool isDark) {
    return Row(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6C5CE7),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : const Color(0xFF98A2B3),
          ),
        ),
      ],
    );
  }

  Widget _buildProBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.15),
            const Color(0xFF00D9FF).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF6C5CE7)),
          const SizedBox(width: 3),
          Text(
            'PRO',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6C5CE7),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildSectionLabel('Account', isDark),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGlassyCard(
            isDark: isDark,
            child: Column(
              children: [
                _buildGlassyMenuItem(
                  icon: Icons.person_outline,
                  title:
                      AppLocalizations.of(context)?.editProfile ??
                      'Edit Profile',
                  iconColor: const Color(0xFF6C5CE7),
                  onTap: () => context.push('/edit-profile'),
                  isDark: isDark,
                ),
                _buildGlassyDivider(isDark),
                _buildGlassyMenuItem(
                  icon: Icons.notifications_outlined,
                  title:
                      AppLocalizations.of(context)?.notifications ??
                      'Notifications',
                  iconColor: const Color(0xFFFF6B6B),
                  onTap: () => context.push('/notifications'),
                  isDark: isDark,
                ),
                _buildGlassyDivider(isDark),
                _buildGlassyMenuItem(
                  icon: Icons.security_outlined,
                  title:
                      AppLocalizations.of(context)?.privacySecurity ??
                      'Privacy & Security',
                  iconColor: const Color(0xFF4ECDC4),
                  onTap: () => context.push('/privacy-security'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildSectionLabel('Preferences', isDark),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGlassyCard(
            isDark: isDark,
            child: Column(
              children: [
                _buildGlassyMenuItem(
                  icon: Icons.palette_outlined,
                  title:
                      AppLocalizations.of(context)?.appearance ?? 'Appearance',
                  iconColor: const Color(0xFFFF8C42),
                  onTap: () => context.push('/appearance'),
                  isDark: isDark,
                ),
                _buildGlassyDivider(isDark),
                _buildGlassyMenuItem(
                  icon: Icons.language_outlined,
                  title: AppLocalizations.of(context)?.language ?? 'Language',
                  iconColor: const Color(0xFF45B7D1),
                  onTap: () => context.push('/language'),
                  isDark: isDark,
                ),
                _buildGlassyDivider(isDark),
                _buildGlassyUnitSystemItem(isDark),
                _buildGlassyDivider(isDark),
                _buildGlassySwitchItem(isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildSectionLabel('Data', isDark),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGlassyCard(
            isDark: isDark,
            child: Column(
              children: [
                _buildGlassyMenuItem(
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
                  isDark: isDark,
                ),
                _buildGlassyDivider(isDark),
                _buildGlassyToggleItem(
                  icon: Icons.article_outlined,
                  title: 'Trucking News',
                  iconColor: const Color(0xFF6C5CE7),
                  value: _showTruckingNews,
                  onChanged: (value) async {
                    await PreferencesService.setShowTruckingNews(value);
                    setState(() {
                      _showTruckingNews = value;
                    });
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildSectionLabel(AppLocalizations.of(context)!.support, isDark),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGlassyCard(
            isDark: isDark,
            child: Column(
              children: [
                _buildGlassyMenuItem(
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  iconColor: const Color(0xFFA29BFE),
                  onTap: () => context.push('/feedback'),
                  isDark: isDark,
                ),
                _buildGlassyDivider(isDark),
                _buildGlassyMenuItem(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  iconColor: const Color(0xFF00CEC9),
                  onTap: () {},
                  isDark: isDark,
                ),
                _buildGlassyDivider(isDark),
                _buildGlassyMenuItem(
                  icon: Icons.system_update_outlined,
                  title: 'Check for Updates',
                  iconColor: const Color(0xFF6C5CE7),
                  onTap: () async {
                    AppDialogs.showLoading(
                      context,
                      message: 'Checking for updates...',
                    );
                    final result = await VersionCheckerService.checkForUpdates(
                      forceCheck: true,
                    );
                    if (!context.mounted) return;
                    AppDialogs.hideLoading(context);

                    if (result.updateAvailable) {
                      AppDialogs.showUpdateAvailable(
                        context,
                        currentVersion: result.currentVersion ?? 'Unknown',
                        latestVersion:
                            result.versionInfo?.latestVersion ?? 'Unknown',
                        downloadUrl: result.versionInfo?.downloadUrl ?? '',
                        changelog: result.versionInfo?.changelog,
                        isCritical: result.isCriticalUpdate,
                      );
                    } else {
                      AppDialogs.showSuccess(
                        context,
                        'You\'re on the latest version!',
                      );
                    }
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildGlassyCard(
        isDark: isDark,
        child: _buildGlassyMenuItem(
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
          isDark: isDark,
          showChevron: false,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : const Color(0xFF667085),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassyCard({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.8),
                      Colors.white.withValues(alpha: 0.6),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassyMenuItem({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
    bool showChevron = true,
  }) {
    final textColor = isDestructive
        ? const Color(0xFFFF6B6B)
        : (isDark ? Colors.white : const Color(0xFF101828));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : const Color(0xFFD0D5DD),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassyDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
    );
  }

  Widget _buildGlassyUnitSystemItem(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF96CEB4).withValues(alpha: 0.2),
                  const Color(0xFF96CEB4).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.straighten_outlined,
              size: 22,
              color: Color(0xFF96CEB4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              AppLocalizations.of(context)?.unitSystem ?? 'Unit System',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
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
                  isDark,
                ),
                _buildSegmentButton(
                  'Imperial',
                  _unitSystem == UnitSystem.imperial,
                  () async {
                    await PreferencesService.setUnitSystem(UnitSystem.imperial);
                    setState(() => _unitSystem = UnitSystem.imperial);
                  },
                  isDark,
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
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : const Color(0xFF667085)),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassySwitchItem(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF74B9FF).withValues(alpha: 0.2),
                  const Color(0xFF74B9FF).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_outlined,
              size: 22,
              color: Color(0xFF74B9FF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              AppLocalizations.of(context)?.showWeather ?? 'Show Weather',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _showWeather,
              onChanged: (value) async {
                await PreferencesService.setShowWeather(value);
                setState(() => _showWeather = value);
              },
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF6C5CE7),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassyToggleItem({
    required IconData icon,
    required String title,
    required Color iconColor,
    required bool value,
    required Function(bool) onChanged,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withValues(alpha: 0.2),
                  iconColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: (val) => onChanged(val),
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF6C5CE7),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}
