import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/permission_provider.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/providers/app_info_provider.dart';

class GeneralPanel extends ConsumerStatefulWidget {
  const GeneralPanel({super.key});

  @override
  ConsumerState<GeneralPanel> createState() => _GeneralPanelState();
}

class _GeneralPanelState extends ConsumerState<GeneralPanel> {
  final List<String> _languages = ['English', 'Spanish', 'French', 'German'];
  final List<String> _mapProviders = [
    'Default Map',
    'Google Maps',
    'OpenStreetMap',
  ];

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final prefs = ref.watch(userPreferencesProvider);
    final canManageUsers = ref.canRead('admin') || ref.canRead('roles');

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'General Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        Text(
          'Configure your workspace, appearance, and default fleet settings.',
          style: GoogleFonts.outfit(
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 24),

        if (canManageUsers) ...[
          _buildCategory(
            context,
            title: 'Workspace',
            description:
                'Manage team access, roles, and administrative permissions.',
            icon: FluentIcons.organization_24_regular,
            children: [
              _buildSettingRow(
                context,
                title: 'Team Management',
                subtitle: 'Manage user access, roles, and groups.',
                control: FilledButton(
                  onPressed: () => context.go('/settings/users-roles'),
                  child: const Text('Manage'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        _buildCategory(
          context,
          title: 'Appearance & Language',
          description: 'Customize the look and feel of your application.',
          icon: FluentIcons.color_24_regular,
          children: [
            _buildSettingRow(
              context,
              title: 'App Theme',
              subtitle: 'Switch between light, dark, or system theme.',
              control: ComboBox<ThemeMode>(
                value: themeMode,
                items: const [
                  ComboBoxItem(value: ThemeMode.light, child: Text('Light')),
                  ComboBoxItem(value: ThemeMode.dark, child: Text('Dark')),
                  ComboBoxItem(value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeProvider.notifier).setTheme(mode);
                  }
                },
              ),
            ),
            const Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            _buildSettingRow(
              context,
              title: 'Language',
              subtitle:
                  'Default language for buttons, labels, and notifications.',
              control: ComboBox<String>(
                value: prefs.language,
                items: _languages
                    .map((e) => ComboBoxItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(userPreferencesProvider.notifier).setLanguage(val);
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        _buildCategory(
          context,
          title: 'Fleet Defaults',
          description:
              'Set default configurations for maps and data synchronization.',
          icon: FluentIcons.vehicle_truck_profile_24_regular,
          children: [
            _buildSettingRow(
              context,
              title: 'Map Provider',
              subtitle: 'Default map layer for routing and vehicle tracking.',
              control: ComboBox<String>(
                value: prefs.mapProvider,
                items: _mapProviders
                    .map((e) => ComboBoxItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(userPreferencesProvider.notifier)
                        .setMapProvider(val);
                  }
                },
              ),
            ),
            const Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            _buildSettingRow(
              context,
              title: 'Sync Frequency',
              subtitle: 'How often the app checks for server updates.',
              control: SizedBox(
                width: 150,
                child: Slider(
                  value: prefs.syncFrequency,
                  min: 10.0,
                  max: 100.0,
                  onChanged: (v) {
                    ref
                        .read(userPreferencesProvider.notifier)
                        .setSyncFrequency(v);
                  },
                  label: '${prefs.syncFrequency.toInt()} min',
                ),
              ),
            ),
            const Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            _buildSettingRow(
              context,
              title: 'Unit System',
              subtitle: 'Distance and weight measurement standards.',
              control: ComboBox<String>(
                value: prefs.unitSystem,
                items: const [
                  ComboBoxItem(value: 'Imperial', child: Text('Imperial')),
                  ComboBoxItem(value: 'Metric', child: Text('Metric')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(userPreferencesProvider.notifier)
                        .setUnitSystem(val);
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        _buildCategory(
          context,
          title: 'About',
          description: 'Package versioning and legal documentation.',
          icon: FluentIcons.info_24_regular,
          children: [
            _buildSettingRow(
              context,
              title: 'Privacy Policy',
              subtitle: 'Read our latest privacy policy and data usage.',
              control: HyperlinkButton(
                child: const Text('View'),
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.maninder.co.in/milow/privacypolicy',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
            ),
            const Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            _buildSettingRow(
              context,
              title: 'Terms of Service',
              subtitle: 'Read our platform terms and conditions.',
              control: HyperlinkButton(
                child: const Text('View'),
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.maninder.co.in/milow/termsandconditions',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
            ),
            const Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            _buildSettingRow(
              context,
              title: 'App Version',
              subtitle: 'Installed software version and build number.',
              control: ref
                  .watch(appInfoProvider)
                  .when(
                    data: (info) => Text(
                      'v${info.version} (build ${info.buildNumber})',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500,
                        color: FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                      ),
                    ),
                    loading: () => const Text('Loading...'),
                    error: (_, _) => const Text('Unknown'),
                  ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        _buildCategory(
          context,
          title: 'Account',
          description: 'Manage your active session and security.',
          icon: FluentIcons.person_24_regular,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Button(
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.all(Colors.red.normal),
                  ),
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  child: const Text('Sign Out'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildCategory(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: FluentTheme.of(context).accentColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: FluentTheme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FluentTheme.of(
                context,
              ).resources.dividerStrokeColorDefault,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget control,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: FluentTheme.of(
                      context,
                    ).resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}
