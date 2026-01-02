import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/user_repository_provider.dart';
import '../../inbox/data/message_repository.dart';
import '../../../../core/constants/app_colors.dart';

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
                          icon: const Icon(FluentIcons.dismiss_24_regular),
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
                          icon: const Icon(FluentIcons.dismiss_24_regular),
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
              icon: const Icon(FluentIcons.dismiss_24_regular),
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
              icon: const Icon(FluentIcons.dismiss_24_regular),
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
                  child: Icon(FluentIcons.search_24_regular),
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
                  Icon(FluentIcons.arrow_clockwise_24_regular),
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
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Email',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Role',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w500,
                                    color: theme.resources.textFillColorPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  user.email ?? '-',
                                  style: GoogleFonts.outfit(
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
                                                FluentIcons
                                                    .checkmark_24_regular,
                                                color: AppColors.success,
                                              )
                                            : Icon(
                                                FluentIcons.warning_24_regular,
                                                color: AppColors.warning,
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
                                          icon: const Icon(
                                            FluentIcons.mail_24_regular,
                                          ),
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
                  icon: const Icon(FluentIcons.chevron_left_24_regular),
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
                  icon: const Icon(FluentIcons.chevron_right_24_regular),
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
        style: GoogleFonts.outfit(
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
        color = AppColors.roleAdmin;
        break;
      case UserRole.dispatcher:
        color = AppColors.roleDispatcher;
        break;
      case UserRole.safetyOfficer:
        color = AppColors.roleSafetyOfficer;
        break;
      case UserRole.driver:
        color = AppColors.roleDriver;
        break;
      case UserRole.assistant:
        color = AppColors.roleAssistant;
        break;
      case UserRole.pending:
        color = AppColors.rolePending;
        break;
      case UserRole.accountant:
        color = AppColors.roleAccountant;
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
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
