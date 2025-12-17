import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
              const Divider(),
              ListTile(
                title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                leading: Icon(FluentIcons.sign_out, color: Colors.red),
                trailing: const Icon(FluentIcons.chevron_right),
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Active Users'),
        const SizedBox(height: 8),
        _buildActiveUsersSection(),
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

  Widget _buildActiveUsersSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(child: Center(child: ProgressBar()));
        }

        final users = snapshot.data!;

        if (users.isEmpty) {
          return Card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No users found',
                  style: TextStyle(
                    color: FluentTheme.of(context).typography.caption?.color,
                  ),
                ),
              ),
            ),
          );
        }

        return Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < users.length; i++) ...[
                _buildUserTile(users[i]),
                if (i < users.length - 1) const Divider(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final String name = user['full_name'] ?? 'Unknown User';
    final String? avatarUrl = user['avatar_url'];
    final String role = user['role'] ?? 'pending';
    final DateTime? createdAt = user['created_at'] != null
        ? DateTime.tryParse(user['created_at'])
        : null;
    final bool isVerified = user['is_verified'] ?? false;

    // Format role label
    String roleLabel = role
        .split('_')
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');

    // Format join date
    String joinDate = 'Unknown';
    if (createdAt != null) {
      final now = DateTime.now();
      final diff = now.difference(createdAt);
      if (diff.inDays < 1) {
        joinDate = 'Today';
      } else if (diff.inDays < 7) {
        joinDate = '${diff.inDays}d ago';
      } else if (diff.inDays < 30) {
        joinDate = '${(diff.inDays / 7).floor()}w ago';
      } else {
        joinDate = '${createdAt.month}/${createdAt.day}/${createdAt.year}';
      }
    }

    return Builder(
      builder: (context) {
        return ListTile(
          leading: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitialsAvatar(context, name);
                    },
                  ),
                )
              : _buildInitialsAvatar(context, name),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (!isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getRoleColor(role),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Joined $joinDate',
                style: TextStyle(
                  fontSize: 11,
                  color: FluentTheme.of(context).typography.caption?.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInitialsAvatar(BuildContext context, String name) {
    String initials = '?';
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).accentColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'dispatcher':
        return Colors.orange;
      case 'safety_officer':
        return Colors.purple;
      case 'driver':
        return Colors.green;
      case 'assistant':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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
                        ).typography.caption?.color?.withValues(alpha: 0.6),
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
