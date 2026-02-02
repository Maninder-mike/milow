import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
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
        if (canManageUsers) ...[
          _buildSectionHeader('Workspace'),
          const SizedBox(height: 8),
          _buildSettingsCard(
            children: [
              _buildRow(
                'Users, Roles, Groups',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage team access',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => context.go('/settings/users-roles'),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],

        _buildSectionHeader('Appearance & Language'),
        const SizedBox(height: 8),
        _buildSettingsCard(
          children: [
            _buildRow(
              'App Theme',
              ComboBox<ThemeMode>(
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
            const SizedBox(height: 16),
            _buildRow(
              'Language',
              ComboBox<String>(
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
        const SizedBox(height: 32),

        _buildSectionHeader('Fleet Defaults'),
        const SizedBox(height: 8),
        _buildSettingsCard(
          children: [
            _buildRow(
              'Default Map Provider',
              ComboBox<String>(
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
            const SizedBox(height: 16),
            _buildRow(
              'Sync Frequency',
              SizedBox(
                width: 200,
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
            const SizedBox(height: 16),
            _buildRow(
              'Unit System',
              ComboBox<String>(
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

        const SizedBox(height: 32),

        _buildSectionHeader('About'),
        const SizedBox(height: 8),
        _buildSettingsCard(
          children: [
            _buildRow(
              'Privacy Policy',
              HyperlinkButton(
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
            const SizedBox(height: 16),
            _buildRow(
              'Terms of Service',
              HyperlinkButton(
                child: const Text('View'),
                onPressed: () {
                  // Placeholder for terms
                },
              ),
            ),
            const Divider(
              style: DividerThemeData(
                horizontalMargin: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            _buildRow(
              'App Version',
              ref
                  .watch(appInfoProvider)
                  .when(
                    data: (info) => Text(
                      'v${info.version} (build ${info.buildNumber})',
                      style: GoogleFonts.outfit(
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
        _buildSectionHeader('Account'),
        const SizedBox(height: 8),
        Align(
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
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: FluentTheme.of(context).resources.textFillColorPrimary,
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, Widget control) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: FluentTheme.of(context).resources.textFillColorPrimary,
          ),
        ),
        control,
      ],
    );
  }
}
