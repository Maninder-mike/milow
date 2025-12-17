import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/user_repository_provider.dart';
import '../../inbox/data/message_repository.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(usersProvider.notifier).setSearch(query);
    });
  }

  Future<void> _sendMessage(UserProfile user) async {
    _messageController.clear();
    await showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text('Message ${user.fullName ?? 'User'}'),
        content: TextBox(
          controller: _messageController,
          placeholder: 'Type your message...',
          maxLines: 3,
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (_messageController.text.trim().isNotEmpty) {
                try {
                  await ref
                      .read(messageRepositoryProvider)
                      .sendMessage(
                        receiverId: user.id,
                        content: _messageController.text.trim(),
                      );
                  if (mounted) {
                    displayInfoBar(
                      context,
                      builder: (context, close) => InfoBar(
                        title: const Text('Sent'),
                        content: const Text('Message sent successfully'),
                        severity: InfoBarSeverity.success,
                        action: IconButton(
                          icon: const Icon(FluentIcons.clear),
                          onPressed: close,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    displayInfoBar(
                      context,
                      builder: (context, close) => InfoBar(
                        title: const Text('Error'),
                        content: Text(e.toString()),
                        severity: InfoBarSeverity.error,
                        action: IconButton(
                          icon: const Icon(FluentIcons.clear),
                          onPressed: close,
                        ),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    UserProfile user, {
    UserRole? newRole,
    bool? isVerified,
  }) async {
    showDialog(
      context: context,
      builder: (ctx) => const ContentDialog(
        content: SizedBox(height: 50, child: Center(child: ProgressRing())),
      ),
    );

    try {
      await ref
          .read(userRepositoryProvider)
          .updateUserStatus(
            userId: user.id,
            role: newRole,
            isVerified: isVerified,
          );
      if (!mounted) return;
      Navigator.pop(context); // Close loader
      ref.read(usersProvider.notifier).refresh(); // Refresh list

      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Success'),
            content: Text('Status updated for ${user.fullName ?? 'User'}'),
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
    final theme = FluentTheme.of(context);

    // Use simpler theme properties to avoid undefined resource errors
    final headerColor = theme.cardColor;
    final rowHoverColor = theme.accentColor.withValues(alpha: 0.1);
    final borderColor = theme.resources.dividerStrokeColorDefault;

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('User Management'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 250,
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search users...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(FluentIcons.search),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: () => context.go('/users/new'),
              child: const Text('Add User'),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: () => ref.read(usersProvider.notifier).refresh(),
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
      content: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
              color: headerColor,
            ),
            child: Row(
              children: [
                const SizedBox(width: 50), // Avatar space
                Expanded(
                  flex: 3,
                  child: Text(
                    'Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Email',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Role',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 100), // Actions space
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: usersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                final currentUserId =
                    Supabase.instance.client.auth.currentUser?.id;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelf = user.id == currentUserId;

                    return HoverButton(
                      onPressed: () {
                        // Detail view or edit could go here
                      },
                      builder: (context, states) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: states.isHovered
                                ? rowHoverColor
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: borderColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: _buildUserAvatar(user),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  user.fullName ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  user.email ?? '-',
                                  style: TextStyle(
                                    color:
                                        theme.resources.textFillColorSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: isSelf
                                      ? _buildRoleBadge(user.role)
                                      : ComboBox<UserRole>(
                                          value: user.role,
                                          placeholder: Text(user.role.label),
                                          items: UserRole.values.map((role) {
                                            return ComboBoxItem(
                                              value: role,
                                              child: _buildRoleBadge(role),
                                            );
                                          }).toList(),
                                          onChanged: (newRole) {
                                            if (newRole != null &&
                                                newRole != user.role) {
                                              _updateStatus(
                                                user,
                                                newRole: newRole,
                                              );
                                            }
                                          },
                                        ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: isSelf
                                      ? (user.isVerified
                                            ? Icon(
                                                FluentIcons.check_mark,
                                                color: Colors.green,
                                              )
                                            : Icon(
                                                FluentIcons.warning,
                                                color:
                                                    Colors.warningPrimaryColor,
                                              ))
                                      : ToggleSwitch(
                                          checked: user.isVerified,
                                          onChanged: (val) {
                                            _updateStatus(
                                              user,
                                              isVerified: val,
                                            );
                                          },
                                          content: Text(
                                            user.isVerified
                                                ? 'Verified'
                                                : 'Pending',
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isSelf)
                                      Tooltip(
                                        message: 'Send Message',
                                        child: IconButton(
                                          icon: const Icon(FluentIcons.mail),
                                          onPressed: () => _sendMessage(user),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
                      onPressed: () =>
                          ref.read(usersProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pagination Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
              color: headerColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Page: '),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FluentIcons.chevron_left),
                  onPressed:
                      (ref.watch(usersProvider).asData?.value.isNotEmpty ==
                              true &&
                          ref.read(usersProvider.notifier).page > 0)
                      ? () {
                          final currentPage = ref
                              .read(usersProvider.notifier)
                              .page;
                          if (currentPage > 0) {
                            ref
                                .read(usersProvider.notifier)
                                .setPage(currentPage - 1);
                          }
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('${ref.watch(usersProvider.notifier).page + 1}'),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.chevron_right),
                  onPressed:
                      (ref.watch(usersProvider).asData?.value.length ==
                          ref.read(usersProvider.notifier).pageSize)
                      ? () {
                          final currentPage = ref
                              .read(usersProvider.notifier)
                              .page;
                          ref
                              .read(usersProvider.notifier)
                              .setPage(currentPage + 1);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(UserProfile user) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          user.avatarUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsAvatar(user);
          },
        ),
      );
    }
    return _buildInitialsAvatar(user);
  }

  Widget _buildInitialsAvatar(UserProfile user) {
    String initials = '?';
    if (user.fullName != null && user.fullName!.isNotEmpty) {
      final parts = user.fullName!.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    } else if (user.email != null && user.email!.isNotEmpty) {
      initials = user.email![0].toUpperCase();
    }

    return Container(
      width: 32,
      height: 32,
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
          fontSize: 12,
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
      case UserRole.pending:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
