import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow_core/milow_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../notifications/data/notification_provider.dart';
import '../../../../core/providers/connectivity_provider.dart';

class StatusBar extends ConsumerStatefulWidget {
  const StatusBar({super.key});

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar> {
  final FlyoutController _flyoutController = FlyoutController();
  Timer? _offlineDebounceTimer;
  bool _confirmedOffline = false;

  @override
  void dispose() {
    _offlineDebounceTimer?.cancel();
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final pendingCount = pendingUsersAsync.maybeWhen(
      data: (users) => users.length,
      orElse: () => 0,
    );

    // Listen for new pending users to show toast
    ref.listen<AsyncValue<List<UserProfile>>>(pendingUsersProvider, (
      previous,
      next,
    ) {
      next.whenData((nextUsers) {
        previous?.whenData((prevUsers) {
          // If we have more users than before, find the new ones
          if (nextUsers.length > prevUsers.length) {
            final newUsers = nextUsers
                .where((n) => !prevUsers.any((p) => p.id == n.id))
                .toList();

            for (var user in newUsers) {
              _showNotificationToast(context, user);
            }
          }
        });
      });
    });

    // Listen to connectivity changes
    ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider, (
      previous,
      next,
    ) {
      next.whenData((results) {
        final isOffline = results.contains(ConnectivityResult.none);

        if (isOffline) {
          // If already confirmed offline, nothing to do
          if (_confirmedOffline) return;

          // If timer is already running, let it run
          if (_offlineDebounceTimer?.isActive ?? false) return;

          // Start debounce timer (e.g. 2 seconds) to ignore transient states
          _offlineDebounceTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _showOfflineNotification(context);
              _confirmedOffline = true;
            }
          });
        } else {
          // We are online
          // Cancel any pending offline timer
          _offlineDebounceTimer?.cancel();

          if (_confirmedOffline) {
            // We were genuinely offline before, so show "Back Online"
            _showOnlineNotification(context);
            _confirmedOffline = false;
          }
        }
      });
    });

    return Container(
      height: 22,
      color: const Color(0xFF007ACC), // VS Code Blue
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Spacer(),
          // Right items
          FlyoutTarget(
            controller: _flyoutController,
            child: GestureDetector(
              onTap: () {
                _flyoutController.showFlyout(
                  builder: (context) {
                    return FlyoutContent(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: _buildNotificationList(pendingUsersAsync),
                    );
                  },
                );
              },
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  _buildItem(FluentIcons.ringer, '', marginRight: 8),
                  if (pendingCount > 0)
                    Positioned(
                      top: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationToast(BuildContext context, UserProfile user) {
    displayInfoBar(
      context,
      duration: const Duration(seconds: 10),
      alignment: Alignment.bottomRight,
      builder: (context, close) {
        return InfoBar(
          title: Text('New Approval Request'),
          content: Text(
            '${user.fullName ?? 'Unknown'} requested ${user.role.label}',
          ),
          severity: InfoBarSeverity.info,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                onPressed: () {
                  ref
                      .read(notificationActionsProvider)
                      .approveUser(user.id, user.role);
                  close();
                },
                child: const Text('Approve'),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () {
                  ref.read(notificationActionsProvider).rejectUser(user.id);
                  close();
                },
                child: const Text('Reject'),
              ),
            ],
          ),
          onClose: close,
        );
      },
    );
  }

  void _showOfflineNotification(BuildContext context) {
    displayInfoBar(
      context,
      duration: const Duration(
        seconds: 5,
      ), // Auto dismiss after 5 seconds or keep?
      alignment: Alignment.bottomRight,
      builder: (context, close) {
        return InfoBar(
          title: const Text('No Internet Connection'),
          content: const Text(
            'You are currently offline. Some features may not be available.',
          ),
          severity: InfoBarSeverity.error,
          onClose: close,
        );
      },
    );
  }

  void _showOnlineNotification(BuildContext context) {
    displayInfoBar(
      context,
      duration: const Duration(seconds: 4),
      alignment: Alignment.bottomRight,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Back Online'),
          content: const Text('Your internet connection has been restored.'),
          severity: InfoBarSeverity.success,
          onClose: close,
        );
      },
    );
  }

  Widget _buildNotificationList(AsyncValue<List<UserProfile>> usersAsync) {
    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No pending approvals'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              title: Text(
                user.fullName ?? 'Unknown User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email ?? 'No email'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Requested: ${user.role.label}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(FluentIcons.check_mark, color: Colors.green),
                    onPressed: () {
                      ref
                          .read(notificationActionsProvider)
                          .approveUser(user.id, user.role);
                      Navigator.of(context).pop(); // Close flyout or keep open?
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(FluentIcons.clear, color: Colors.red),
                    onPressed: () {
                      ref.read(notificationActionsProvider).rejectUser(user.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () =>
          const SizedBox(height: 50, child: Center(child: ProgressRing())),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Error: $err\nStack: $stack',
          style: TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildItem(IconData icon, String text, {double marginRight = 0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
          ),
        ],
        if (marginRight > 0) SizedBox(width: marginRight),
      ],
    );
  }
}
