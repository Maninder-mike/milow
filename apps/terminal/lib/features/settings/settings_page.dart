import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'utils/update_checker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        _buildSectionHeader('Account'),
        const SizedBox(height: 8),
        Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                title: const Text('My Profile'),
                subtitle: const Text('Manage your account details'),
                leading: const Icon(FluentIcons.contact),
                trailing: const Icon(FluentIcons.chevron_right),
                onPressed: () {
                  context.go('/profile');
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Security'),
                leading: const Icon(FluentIcons.lock),
                trailing: const Icon(FluentIcons.chevron_right),
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('General'),
        const SizedBox(height: 8),
        Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildSwitchTile('Dark Mode', true, (val) {}),
              const Divider(),
              _buildSwitchTile('Notifications', false, (val) {}),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('About'),
        const SizedBox(height: 8),
        _buildAboutSection(),
      ],
    );
  }

  Widget _buildAboutSection() {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ProgressBar();
        }

        final info = snapshot.data!;
        return Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  FluentIcons.robot,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.appName, // "terminal" usually, might want to capitalize
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version ${info.version} (Build ${info.buildNumber})',
                      style: TextStyle(
                        color: FluentTheme.of(
                          context,
                        ).typography.caption?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Milow Terminal Application for macOS.'),
                    const SizedBox(height: 16),
                    Text(
                      '© ${DateTime.now().year} Maninder-mike. All rights reserved.',
                      style: TextStyle(
                        fontSize: 10,
                        color: FluentTheme.of(
                          context,
                        ).typography.caption?.color?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Button(
                      child: const Text('Check for Updates'),
                      onPressed: () {
                        checkForUpdates(
                          context,
                        ); // Assuming this function is defined elsewhere or imported
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title),
      trailing: ToggleSwitch(checked: value, onChanged: onChanged),
    );
  }
}
