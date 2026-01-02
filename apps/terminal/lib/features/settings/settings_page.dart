import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/theme_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Local state for UI toggles (mocking backend/prefs for now)
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  double _syncFrequency = 50.0;
  String _selectedLanguage = 'English';
  String _selectedMapProvider = 'Default Map';
  String _appVersion = '';

  final List<String> _languages = ['English', 'Spanish', 'French', 'German'];
  final List<String> _mapProviders = [
    'Default Map',
    'Google Maps',
    'OpenStreetMap',
  ];

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version} (build ${info.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current theme from provider
    final themeMode = ref.watch(themeProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        // General Section
        _buildSectionHeader('General'),
        const SizedBox(height: 8),
        _buildSettingsCard(
          children: [
            _buildRow(
              'App Theme (Light/Dark/System)',
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
            // TODO: Implement language switching with localization (flutter_localizations)
            _buildRow(
              'Language',
              ComboBox<String>(
                value: _selectedLanguage,
                items: _languages
                    .map((e) => ComboBoxItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Notifications Section
        _buildSectionHeader('Notifications'),
        const SizedBox(height: 8),
        _buildSettingsCard(
          children: [
            _buildRow(
              'Push Notifications',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_pushNotifications ? 'On' : 'Off'),
                  const SizedBox(width: 12),
                  ToggleSwitch(
                    checked: _pushNotifications,
                    onChanged: (v) => setState(() => _pushNotifications = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildRow(
              'Email Alerts',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_emailAlerts ? 'On' : 'Off'),
                  const SizedBox(width: 12),
                  ToggleSwitch(
                    checked: _emailAlerts,
                    onChanged: (v) => setState(() => _emailAlerts = v),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Fleet Management Section
        _buildSectionHeader('Fleet Management'),
        const SizedBox(height: 8),
        _buildSettingsCard(
          children: [
            _buildRow(
              'Default Map Provider',
              ComboBox<String>(
                value: _selectedMapProvider,
                items: _mapProviders
                    .map((e) => ComboBoxItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMapProvider = val);
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildRow(
              'Sync Frequency',
              SizedBox(
                width: 200,
                child: Slider(
                  value: _syncFrequency,
                  min: 0,
                  max: 100,
                  onChanged: (v) => setState(() => _syncFrequency = v),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Account Section
        _buildSectionHeader('Account'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Button(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Sign Out'),
          ),
        ),

        const SizedBox(height: 24),

        // Footer Links
        Row(
          children: [
            HyperlinkButton(
              child: const Text('Privacy Policy'),
              onPressed: () async {
                final url = Uri.parse(
                  'https://www.maninder.co.in/milow/privacypolicy',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
            const SizedBox(width: 16),
            HyperlinkButton(
              child: const Text('Terms of Service'),
              onPressed: () {
                // Placeholder for terms
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Version ${_appVersion.isEmpty ? 'Loading...' : _appVersion}',
            style: GoogleFonts.outfit(
              color: FluentTheme.of(context).resources.textFillColorSecondary,
              fontSize: 12,
            ),
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
