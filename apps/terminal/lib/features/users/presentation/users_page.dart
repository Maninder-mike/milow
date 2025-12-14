import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/user_repository_provider.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  Future<void> _updateRole(UserProfile user, UserRole newRole) async {
    showDialog(
      context: context,
      builder: (ctx) => const ContentDialog(
        content: SizedBox(height: 50, child: Center(child: ProgressRing())),
      ),
    );

    try {
      await ref.read(userRepositoryProvider).updateUserRole(user.id, newRole);
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      ref.invalidate(usersProvider); // Refresh list
      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Success'),
            content: Text('Role updated for ${user.fullName}'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'User Management',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => context.go('/users/new'),
              child: const Text('Add User'),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: () => ref.invalidate(usersProvider),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  child: ListTile(
                    leading: const Icon(FluentIcons.contact),
                    title: Text(user.fullName),
                    subtitle: Text(user.email ?? '-'),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(child: _buildRoleBadge(user.role)),
                          const SizedBox(width: 16),
                          Flexible(
                            child: ComboBox<UserRole>(
                              value: user.role,
                              items: UserRole.values.map((role) {
                                return ComboBoxItem(
                                  value: role,
                                  child: Text(
                                    role.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (newRole) {
                                if (newRole != null && newRole != user.role) {
                                  _updateRole(user, newRole);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading users: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(usersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color color;
    switch (role) {
      case UserRole.admin:
        color = Colors.red;
        break;
      case UserRole.dispatcher:
        color = Colors.orange;
        break;
      case UserRole.safetyOfficer:
        color = Colors.purple;
        break;
      case UserRole.driver:
        color = Colors.green;
        break;
      case UserRole.assistant:
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
