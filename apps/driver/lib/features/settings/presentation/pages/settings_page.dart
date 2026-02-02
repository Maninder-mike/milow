import 'package:flutter/material.dart';
import 'dart:async';
import 'package:milow/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/auth_service.dart';
import 'package:milow/core/services/profile_repository.dart';
import 'package:milow/core/services/preferences_service.dart';

import 'package:milow/core/widgets/auth_wrapper.dart';
import 'package:milow/features/settings/presentation/pages/about_page.dart';

import 'package:milow/core/services/trip_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _fullName;
  String? _email;
  String? _avatarUrl;

  String _distanceUnit = 'km';
  int _tripCount = 0;
  double _totalMiles = 0;
  String _appVersion = '';

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
      final totalDistance =
          await TripService.getTotalDistance(); // stored in miles

      // Calculate distance based on distance unit preference
      final isMetric = _distanceUnit == 'km';
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
    final dUnit = await PreferencesService.getDistanceUnit();

    // Fetch app version info
    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      _distanceUnit = dUnit;
      _appVersion = packageInfo.version;
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final textColor = tokens.textPrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Settings',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(context, userName, userEmail),
              SizedBox(height: tokens.spacingL),
              _buildAccountSection(context, textColor),
              SizedBox(height: tokens.spacingL),
              _buildPreferencesSection(context, textColor),
              SizedBox(height: tokens.spacingL),
              _buildDataSection(context, textColor),
              SizedBox(height: tokens.spacingL),
              _buildSupportSection(context, textColor),
              SizedBox(height: tokens.spacingXL),
              _buildSignOutSection(context, textColor),
              // Version Footer
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: tokens.spacingL),
                  child: Column(
                    children: [
                      Text(
                        'Milow Driver v$_appVersion',
                        style: textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.4),
                        ),
                      ),
                      Text(
                        'Built with ❤️ for Drivers',
                        style: textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + tokens.spacingL,
              ),
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
  ) {
    return Container(
      width: double.infinity,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      padding: EdgeInsets.fromLTRB(
        context.tokens.spacingL,
        context.tokens.spacingS,
        context.tokens.spacingL,
        context.tokens.spacingXL,
      ),
      child: InkWell(
        onTap: () => context.push('/edit-profile'),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? NetworkImage(_avatarUrl!)
                      : null,
                  child: _avatarUrl == null || _avatarUrl!.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 12,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: context.tokens.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: context.tokens.spacingS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'PRO',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.tokens.spacingM),
                  Row(
                    children: [
                      _buildStatBadge(
                        context,
                        _tripCount.toString(),
                        AppLocalizations.of(context)!.trips,
                      ),
                      SizedBox(width: context.tokens.spacingM),
                      _buildStatBadge(
                        context,
                        _totalMiles >= 1000
                            ? '${(_totalMiles / 1000).toStringAsFixed(1)}K'
                            : _totalMiles.toStringAsFixed(0),
                        _distanceUnit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(context.tokens.shapeS),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('ACCOUNT', textColor),
        _buildMenuItem(
          icon: Icons.person_outline_rounded,
          title: AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',
          iconColor: Theme.of(context).colorScheme.primary,
          onTap: () => context.push('/edit-profile'),
          textColor: textColor,
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.notifications_none_rounded,
          title: AppLocalizations.of(context)?.notifications ?? 'Notifications',
          iconColor: Colors.orange,
          onTap: () => context.push('/notifications'),
          textColor: textColor,
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.lock_outline_rounded,
          title:
              AppLocalizations.of(context)?.privacySecurity ??
              'Privacy & Security',
          iconColor: Colors.blue,
          onTap: () => context.push('/privacy-security'),
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('PREFERENCES', textColor),
        _buildMenuItem(
          icon: Icons.palette_outlined,
          title: AppLocalizations.of(context)?.appearance ?? 'Appearance',
          iconColor: Colors.purple,
          onTap: () => context.push('/appearance'),
          textColor: textColor,
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.translate_rounded,
          title: AppLocalizations.of(context)?.language ?? 'Language',
          iconColor: Colors.teal,
          onTap: () => context.push('/language'),
          textColor: textColor,
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.straighten_rounded,
          title: 'Units',
          iconColor: Colors.teal,
          onTap: () async {
            await context.push('/units-settings');
            await _loadPreferences(); // Reload in case distance unit changed
          },
          textColor: textColor,
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.handyman_outlined,
          title: 'Driver Tools',
          iconColor: Colors.orange,
          onTap: () => context.push('/driver-tools'),
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context, Color textColor) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [],
    );
  }

  Widget _buildSupportSection(BuildContext context, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          AppLocalizations.of(context)!.support.toUpperCase(),
          textColor,
        ),
        _buildMenuItem(
          icon: Icons.feedback_outlined,
          title: 'Send Feedback',
          iconColor: Colors.blueGrey,
          onTap: () => context.push('/feedback'),
          textColor: textColor,
        ),
        _buildDivider(),
        _buildMenuItem(
          icon: Icons.info_outline_rounded,
          title: 'About Milow',
          iconColor: Colors.grey,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutPage()),
          ),
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildSignOutSection(BuildContext context, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMenuItem(
          icon: Icons.logout_rounded,
          title: AppLocalizations.of(context)?.signOut ?? 'Sign Out',
          iconColor: context.tokens.error,
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
      ],
    );
  }

  Widget _buildSectionLabel(String label, Color textColor) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.tokens.spacingL,
        context.tokens.spacingXL,
        context.tokens.spacingL,
        context.tokens.spacingS,
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
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
    final finalTextColor = isDestructive ? context.tokens.error : textColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.tokens.spacingL,
            vertical: 18,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isDestructive
                    ? finalTextColor
                    : context.tokens.textSecondary,
              ),
              SizedBox(width: context.tokens.spacingL),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: finalTextColor,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                  size: 24,
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
      thickness: 0.5,
      indent: context.tokens.spacingL,
      endIndent: 0,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
