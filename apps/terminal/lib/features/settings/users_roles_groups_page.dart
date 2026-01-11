import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Users, Roles, Groups management page
/// Accessible from Settings > Users, Roles, Groups
class UsersRolesGroupsPage extends ConsumerStatefulWidget {
  const UsersRolesGroupsPage({super.key});

  @override
  ConsumerState<UsersRolesGroupsPage> createState() =>
      _UsersRolesGroupsPageState();
}

class _UsersRolesGroupsPageState extends ConsumerState<UsersRolesGroupsPage> {
  int _selectedTab = 0;
  final _manualApprovalEmailController = TextEditingController();

  Future<void> _manualApproveUser() async {
    final email = _manualApprovalEmailController.text.trim();
    if (email.isEmpty) return;

    try {
      // Find user by email (case-insensitive search)
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, is_verified, full_name')
          .ilike('email', email)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('User Not Found'),
              content: Text('No user found with email: $email'),
              severity: InfoBarSeverity.warning,
              action: IconButton(
                icon: const Icon(FluentIcons.dismiss_24_regular),
                onPressed: close,
              ),
            ),
          );
        }
        return;
      }

      // Check if user is already verified
      final isVerified = response['is_verified'] == true;
      final fullName = response['full_name'] ?? email;

      if (isVerified) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) {
              return InfoBar(
                title: const Text('User Already Active'),
                content: Text('$fullName is already in the Active Users list.'),
                severity: InfoBarSeverity.info,
                action: IconButton(
                  icon: const Icon(FluentIcons.dismiss_24_regular),
                  onPressed: close,
                ),
              );
            },
          );
        }
        _manualApprovalEmailController.clear();
        return;
      }

      // Get admin's company_id to assign to the driver
      final adminId = Supabase.instance.client.auth.currentUser?.id;
      String? companyId;
      if (adminId != null) {
        final adminProfile = await Supabase.instance.client
            .from('profiles')
            .select('company_id, company_name')
            .eq('id', adminId)
            .maybeSingle();
        companyId = adminProfile?['company_id'] as String?;
      }

      // Update user - the database trigger `notify_on_verification`
      // automatically sends a notification to the driver when is_verified changes to true.
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_verified': true,
            if (companyId != null) 'company_id': companyId,
            // Verify implies driver role usually in this context, or keep existing
          })
          .eq('email', email);

      if (mounted) {
        _manualApprovalEmailController.clear();
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Success'),
              content: Text('User $email has been approved and notified.'),
              severity: InfoBarSeverity.success,
              action: IconButton(
                icon: const Icon(FluentIcons.dismiss_24_regular),
                onPressed: close,
              ),
            );
          },
        );
        setState(() {}); // Refresh lists
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error'),
              content: Text('Failed to approve user: $e'),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.dismiss_24_regular),
                onPressed: close,
              ),
            );
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _manualApprovalEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'Users, Roles, Groups',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: _selectedTab == 1
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextBox(
                      controller: _manualApprovalEmailController,
                      placeholder: 'Enter requester email',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          FluentIcons.person_add_24_regular,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _manualApproveUser,
                    child: const Text('Approve'),
                  ),
                ],
              )
            : CommandBar(
                mainAxisAlignment: MainAxisAlignment.end,
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.add_24_regular),
                    label: Text(_getAddButtonLabel()),
                    onPressed: _handleAdd,
                  ),
                ],
                secondaryItems: _selectedTab == 0
                    ? [
                        CommandBarButton(
                          icon: const Icon(FluentIcons.arrow_upload_24_regular),
                          label: const Text('Bulk Import'),
                          onPressed: _showBulkImportDialog,
                        ),
                      ]
                    : [],
              ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: TabView(
          currentIndex: _selectedTab,
          onChanged: (index) => setState(() => _selectedTab = index),
          closeButtonVisibility: CloseButtonVisibilityMode.never,
          tabs: [
            Tab(
              key: const ValueKey('settings_tab_users'),
              text: const Text('Users'),
              icon: const Icon(FluentIcons.people_24_regular),
              body: _UsersTab(),
            ),
            Tab(
              key: const ValueKey('settings_tab_drivers'),
              text: const Text('Drivers'),
              icon: const Icon(FluentIcons.vehicle_truck_profile_24_regular),
              body: _DriversTab(),
            ),
            Tab(
              key: const ValueKey('settings_tab_roles'),
              text: const Text('Roles'),
              icon: const Icon(FluentIcons.shield_24_regular),
              body: _RolesTab(),
            ),
            Tab(
              key: const ValueKey('settings_tab_groups'),
              text: const Text('Groups'),
              icon: const Icon(FluentIcons.people_team_24_regular),
              body: _GroupsTab(),
            ),
          ],
        ),
      ),
    );
  }

  String _getAddButtonLabel() {
    switch (_selectedTab) {
      case 0:
        return 'Invite User';
      case 2:
        return 'Create Role';
      case 3:
        return 'Create Group';
      default:
        return 'Add';
    }
  }

  void _handleAdd() {
    switch (_selectedTab) {
      case 0:
        _showInviteUserDialog();
        break;
      case 2:
        _showCreateRoleDialog();
        break;
      case 3:
        _showCreateGroupDialog();
        break;
    }
  }

  void _showInviteUserDialog({bool isDriver = false}) {
    showDialog(
      context: context,
      builder: (context) =>
          _InviteUserDialog(initialRole: isDriver ? 'driver' : null),
    ).then((_) => setState(() {})); // Refresh users list
  }

  void _showCreateRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => const _CreateRoleDialog(),
    ).then((_) => setState(() {})); // Refresh roles list
  }

  void _showCreateGroupDialog() {
    // Groups functionality - future implementation
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Create Group'),
        content: const Text('Groups functionality coming soon.'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog() {
    showDialog(context: context, builder: (context) => _BulkImportDialog());
  }
}

/// Dialog for bulk importing users from CSV
class _BulkImportDialog extends StatefulWidget {
  @override
  State<_BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<_BulkImportDialog> {
  List<Map<String, String>>? _parsedUsers;
  String? _error;
  bool _isImporting = false;
  int _importedCount = 0;
  int _failedCount = 0;

  Future<void> _pickAndParseCSV() async {
    try {
      const typeGroup = XTypeGroup(label: 'CSV files', extensions: ['csv']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) return;

      final content = await file.readAsString();
      final lines = const LineSplitter().convert(content);

      if (lines.isEmpty) {
        setState(() => _error = 'File is empty');
        return;
      }

      // Parse header
      final header = lines.first
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();
      final emailIdx = header.indexOf('email');
      final nameIdx = header.indexOf('full_name');
      final roleIdx = header.indexOf('role_name');

      if (emailIdx == -1) {
        setState(() => _error = 'CSV must have an "email" column');
        return;
      }

      // Parse rows
      final users = <Map<String, String>>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final values = line.split(',').map((e) => e.trim()).toList();
        if (values.length > emailIdx && values[emailIdx].contains('@')) {
          users.add({
            'email': values[emailIdx],
            'full_name': nameIdx >= 0 && values.length > nameIdx
                ? values[nameIdx]
                : '',
            'role_name': roleIdx >= 0 && values.length > roleIdx
                ? values[roleIdx]
                : '',
          });
        }
      }

      if (users.isEmpty) {
        setState(() => _error = 'No valid users found in CSV');
        return;
      }

      setState(() {
        _parsedUsers = users;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to parse CSV: $e');
    }
  }

  String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    return List.generate(
      12,
      (i) =>
          chars[(DateTime.now().microsecondsSinceEpoch + i * 7) % chars.length],
    ).join();
  }

  Future<void> _importUsers() async {
    if (_parsedUsers == null || _parsedUsers!.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importedCount = 0;
      _failedCount = 0;
    });

    final supabase = Supabase.instance.client;

    for (final user in _parsedUsers!) {
      try {
        final password = _generatePassword();
        final response = await supabase.functions.invoke(
          'invite-user',
          body: {
            'email': user['email'],
            'password': password,
            'full_name': user['full_name'],
          },
        );

        if (response.status == 200) {
          setState(() => _importedCount++);
        } else {
          setState(() => _failedCount++);
        }
      } catch (e) {
        setState(() => _failedCount++);
      }
    }

    setState(() => _isImporting = false);

    if (mounted) {
      Navigator.pop(context);
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Import complete'),
          content: Text('Imported: $_importedCount, Failed: $_failedCount'),
          severity: _failedCount == 0
              ? InfoBarSeverity.success
              : InfoBarSeverity.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Bulk Import Users'),
      content: SizedBox(
        width: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Import users from a CSV file with these columns:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FluentTheme.of(context).cardColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: FluentTheme.of(
                    context,
                  ).resources.dividerStrokeColorDefault,
                ),
              ),
              child: Text(
                'email, full_name, role_name',
                style: GoogleFonts.sourceCodePro(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InfoBar(
                  title: const Text('Error'),
                  content: Text(_error!),
                  severity: InfoBarSeverity.error,
                ),
              ),
            if (_parsedUsers == null)
              FilledButton(
                onPressed: _pickAndParseCSV,
                child: const Text('Select CSV File'),
              )
            else ...[
              InfoBar(
                title: Text('${_parsedUsers!.length} users found'),
                content: const Text(
                  'Review the preview below and click Import.',
                ),
                severity: InfoBarSeverity.success,
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: FluentTheme.of(
                      context,
                    ).resources.dividerStrokeColorDefault,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: _parsedUsers!.length.clamp(0, 10),
                  itemBuilder: (context, index) {
                    final user = _parsedUsers![index];
                    return ListTile(
                      title: Text(user['email'] ?? ''),
                      subtitle: Text(user['full_name'] ?? 'No name'),
                    );
                  },
                ),
              ),
              if (_parsedUsers!.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... and ${_parsedUsers!.length - 10} more',
                    style: TextStyle(
                      color: FluentTheme.of(
                        context,
                      ).resources.textFillColorSecondary,
                    ),
                  ),
                ),
            ],
            if (_isImporting) ...[
              const SizedBox(height: 16),
              ProgressBar(
                value:
                    (_importedCount + _failedCount) /
                    _parsedUsers!.length *
                    100,
              ),
              const SizedBox(height: 8),
              Text('Importing... $_importedCount/${_parsedUsers!.length}'),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _isImporting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_parsedUsers != null)
          FilledButton(
            onPressed: _isImporting ? null : _importUsers,
            child: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Text('Import Users'),
          ),
      ],
    );
  }
}

// =============================================================================
// USERS TAB
// =============================================================================

class _UsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading users: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FluentIcons.people_24_regular,
                  size: 48,
                  color: theme.resources.textFillColorSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite users to give them access to the terminal.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _UserListItem(user: user);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final supabase = Supabase.instance.client;
    final currentUserProfile = await supabase
        .from('profiles')
        .select('company_id')
        .eq('id', supabase.auth.currentUser!.id)
        .single();

    final companyId = currentUserProfile['company_id'] as String?;
    if (companyId == null) return [];

    final response = await supabase
        .from('profiles')
        .select('''
          id,
          email,
          full_name,
          role,
          role_id,
          is_verified,
          avatar_url,
          created_at,
          roles(name)
        ''')
        .eq('company_id', companyId)
        .neq('role', 'driver') // Don't show drivers in terminal user management
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }
}

class _UserListItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRevoke;

  const _UserListItem({required this.user, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final roleName =
        user['roles']?['name'] as String? ??
        user['role'] as String? ??
        'No Role';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.accentColor.lighter,
          backgroundImage: user['avatar_url'] != null
              ? NetworkImage(user['avatar_url'] as String)
              : null,
          child: user['avatar_url'] == null
              ? Text(
                  (user['full_name'] as String?)
                          ?.substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: TextStyle(color: theme.accentColor.darkest),
                )
              : null,
        ),
        title: Text(
          user['full_name'] as String? ?? 'Unknown User',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          user['email'] as String? ?? '',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleName,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: theme.accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (onRevoke != null)
              Button(
                onPressed: onRevoke,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    Colors.red.withValues(alpha: 0.1),
                  ),
                  foregroundColor: WidgetStateProperty.all(Colors.red),
                ),
                child: const Text('Revoke'),
              )
            else
              DropDownButton(
                title: const Icon(
                  FluentIcons.more_vertical_24_regular,
                  size: 16,
                ),
                items: [
                  MenuFlyoutItem(
                    leading: const Icon(FluentIcons.key_reset_24_regular),
                    text: const Text('Reset Password'),
                    onPressed: () => _showResetPasswordDialog(context, user),
                  ),
                  const MenuFlyoutSeparator(),
                  MenuFlyoutItem(
                    leading: Icon(
                      FluentIcons.delete_24_regular,
                      color: Colors.red.normal,
                    ),
                    text: Text(
                      'Delete User',
                      style: TextStyle(color: Colors.red.normal),
                    ),
                    onPressed: () => _showDeleteUserDialog(context, user),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Reset Password for ${user['full_name'] ?? user['email']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a new temporary password for this user.'),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'New Password',
              child: TextBox(
                controller: passwordController,
                placeholder: 'Enter new password',
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) return;

              try {
                final supabase = Supabase.instance.client;
                final response = await supabase.functions.invoke(
                  'reset-password',
                  body: {
                    'user_id': user['id'],
                    'new_password': passwordController.text,
                  },
                );

                if (response.status != 200) {
                  throw Exception(
                    response.data?['error'] ?? 'Failed to reset password',
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  displayInfoBar(
                    context,
                    builder: (context, close) => const InfoBar(
                      title: Text('Password reset'),
                      content: Text('Password has been reset successfully.'),
                      severity: InfoBarSeverity.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  displayInfoBar(
                    context,
                    builder: (context, close) => InfoBar(
                      title: const Text('Error'),
                      content: Text('Failed to reset password: $e'),
                      severity: InfoBarSeverity.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${user['full_name'] ?? user['email']}?\n\nThis action cannot be undone.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red.normal),
            ),
            onPressed: () async {
              try {
                // Call edge function to delete user
                final response = await Supabase.instance.client.functions
                    .invoke(
                      'delete-user',
                      body: {'user_id': user['id']},
                      method: HttpMethod.post,
                    );

                if (response.status != 200) {
                  throw Exception(
                    response.data['error'] ?? 'Failed to delete user',
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  await displayInfoBar(
                    context,
                    builder: (context, close) => const InfoBar(
                      title: Text('User deleted'),
                      content: Text('The user has been successfully deleted.'),
                      severity: InfoBarSeverity.success,
                    ),
                  );
                  // Refresh users list if applicable (parent widget handles stream usually)
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(
                    context,
                  ); // Close dialog on error too or keep open? keep open is better but for now match flow
                  await displayInfoBar(
                    context,
                    builder: (context, close) => InfoBar(
                      title: const Text('Error'),
                      content: Text('Failed to delete user: $e'),
                      severity: InfoBarSeverity.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DRIVERS TAB
// =============================================================================

class _DriversTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends ConsumerState<_DriversTab> {
  Future<void> _revokeDriver(String userId, String email) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_verified': false})
          .eq('id', userId);

      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Access Revoked'),
            content: Text('Access for $email has been revoked.'),
            severity: InfoBarSeverity.success,
          ),
        );
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text('Failed to revoke access: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDrivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading drivers: ${snapshot.error}'),
          );
        }

        final drivers = snapshot.data ?? [];

        if (drivers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FluentIcons.vehicle_truck_profile_24_regular,
                  size: 48,
                  color: theme.resources.textFillColorSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No drivers found',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manually approve drivers using the input above.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            return _UserListItem(
              user: driver,
              onRevoke: () =>
                  _revokeDriver(driver['id'] as String, driver['email'] ?? ''),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final supabase = Supabase.instance.client;
    final currentUserProfile = await supabase
        .from('profiles')
        .select('company_id')
        .eq('id', supabase.auth.currentUser!.id)
        .single();

    final companyId = currentUserProfile['company_id'] as String?;
    if (companyId == null) return [];

    final response = await supabase
        .from('profiles')
        .select('''
          id,
          email,
          full_name,
          role,
          role_id,
          is_verified,
          avatar_url,
          created_at,
          roles(name)
        ''')
        .eq('company_id', companyId)
        .eq('role', 'driver')
        .eq('is_data_sharing_enabled', true)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }
}

// =============================================================================
// ROLES TAB
// =============================================================================

class _RolesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRoles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading roles: ${snapshot.error}'));
        }

        final roles = snapshot.data ?? [];

        if (roles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FluentIcons.shield_24_regular,
                  size: 48,
                  color: theme.resources.textFillColorSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No custom roles yet',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create roles to control what users can access.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            return _RoleListItem(role: role);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRoles() async {
    final supabase = Supabase.instance.client;
    final currentUserProfile = await supabase
        .from('profiles')
        .select('company_id')
        .eq('id', supabase.auth.currentUser!.id)
        .single();

    final companyId = currentUserProfile['company_id'] as String?;
    if (companyId == null) return [];

    final response = await supabase
        .from('roles')
        .select('id, name, description, is_system_role, created_at')
        .eq('company_id', companyId)
        .order('name');

    return List<Map<String, dynamic>>.from(response as List);
  }
}

class _RoleListItem extends StatelessWidget {
  final Map<String, dynamic> role;

  const _RoleListItem({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isSystemRole = role['is_system_role'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(FluentIcons.shield_24_regular, color: theme.accentColor),
        ),
        title: Row(
          children: [
            Text(
              role['name'] as String? ?? 'Unknown Role',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
            if (isSystemRole) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.resources.textFillColorTertiary.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SYSTEM',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          role['description'] as String? ?? 'No description',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(FluentIcons.edit_24_regular, size: 16),
          onPressed: isSystemRole
              ? null
              : () {
                  final roleId = role['id'] as String?;
                  if (roleId != null) {
                    context.go('/settings/roles/$roleId');
                  }
                },
        ),
      ),
    );
  }
}

// =============================================================================
// GROUPS TAB (Placeholder)
// =============================================================================

class _GroupsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.people_team_24_regular,
            size: 48,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Groups coming soon',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Group users together for easier management.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: theme.resources.textFillColorTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DIALOGS
// =============================================================================

class _InviteUserDialog extends ConsumerStatefulWidget {
  final String? initialRole;

  const _InviteUserDialog({this.initialRole});

  @override
  ConsumerState<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends ConsumerState<_InviteUserDialog> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRoleId;
  bool _isLoading = false;
  bool _passwordGenerated = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    final password = List.generate(12, (index) {
      return chars[(DateTime.now().microsecondsSinceEpoch + index) %
          chars.length];
    }).join();

    setState(() {
      _passwordController.text = password;
      _passwordGenerated = true;
    });
  }

  Future<void> _inviteUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('Missing fields'),
          content: Text('Email and password are required.'),
          severity: InfoBarSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Call the Edge Function
      final response = await supabase.functions.invoke(
        'invite-user',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _usernameController.text.trim().isNotEmpty
              ? _usernameController.text.trim()
              : null,
          'username': _usernameController.text.trim().isNotEmpty
              ? _usernameController.text.trim()
              : null,
          'role_id': _selectedRoleId,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Failed to invite user';
        throw Exception(error);
      }

      if (mounted) {
        Navigator.pop(context);
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('User invited'),
            content: Text('Invitation sent to ${_emailController.text}'),
            severity: InfoBarSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text('Failed to invite user: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Invite User'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Email',
              child: TextBox(
                controller: _emailController,
                placeholder: 'user@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Username (optional)',
              child: TextBox(
                controller: _usernameController,
                placeholder: 'john.smith',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Temporary Password',
              child: Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _passwordController,
                      placeholder: 'Generate a password',
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: _generatePassword,
                    child: const Text('Generate'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Role',
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchRoles(),
                builder: (context, snapshot) {
                  final roles = snapshot.data ?? [];
                  return ComboBox<String>(
                    value: _selectedRoleId,
                    placeholder: const Text('Select a role'),
                    isExpanded: true,
                    items: roles.map((role) {
                      final isSelected =
                          _selectedRoleId == role['id'] ||
                          (_selectedRoleId == null &&
                              widget.initialRole != null &&
                              role['name'].toString().toLowerCase() ==
                                  widget.initialRole!.toLowerCase());

                      // Auto-select if matches initialRole and nothing selected
                      if (_selectedRoleId == null && isSelected) {
                        Future.microtask(() {
                          if (mounted && _selectedRoleId == null) {
                            setState(
                              () => _selectedRoleId = role['id'] as String,
                            );
                          }
                        });
                      }

                      return ComboBoxItem<String>(
                        value: role['id'] as String,
                        child: Text(role['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedRoleId = value);
                    },
                  );
                },
              ),
            ),
            if (_passwordGenerated) ...[
              const SizedBox(height: 16),
              InfoBar(
                title: const Text('Password generated'),
                content: const Text(
                  'Copy this password and share it securely with the user.',
                ),
                severity: InfoBarSeverity.success,
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _inviteUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Invite'),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRoles() async {
    final supabase = Supabase.instance.client;
    final currentUserProfile = await supabase
        .from('profiles')
        .select('company_id')
        .eq('id', supabase.auth.currentUser!.id)
        .single();

    final companyId = currentUserProfile['company_id'] as String?;
    if (companyId == null) return [];

    final response = await supabase
        .from('roles')
        .select('id, name')
        .eq('company_id', companyId)
        .order('name');

    return List<Map<String, dynamic>>.from(response as List);
  }
}

class _CreateRoleDialog extends ConsumerStatefulWidget {
  const _CreateRoleDialog();

  @override
  ConsumerState<_CreateRoleDialog> createState() => _CreateRoleDialogState();
}

class _CreateRoleDialogState extends ConsumerState<_CreateRoleDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createRole() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUserProfile = await supabase
          .from('profiles')
          .select('company_id')
          .eq('id', supabase.auth.currentUser!.id)
          .single();

      final companyId = currentUserProfile['company_id'] as String?;
      if (companyId == null) {
        throw Exception('No company found');
      }

      await supabase.from('roles').insert({
        'company_id': companyId,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'is_system_role': false,
      });

      if (mounted) {
        Navigator.pop(context);
        // Roles list refreshed by parent
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error'),
              content: Text('Failed to create role: $e'),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.dismiss_24_regular),
                onPressed: close,
              ),
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Create Role'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Role Name',
              child: TextBox(
                controller: _nameController,
                placeholder: 'e.g., Sales Manager',
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Description',
              child: TextBox(
                controller: _descriptionController,
                placeholder: 'Describe what this role can do...',
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            const InfoBar(
              title: Text('Tip'),
              content: Text(
                'After creating the role, you can configure its permissions.',
              ),
              severity: InfoBarSeverity.info,
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _createRole,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
