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

    // Watch driver_left notifications
    final driverLeftAsync = ref.watch(driverLeftNotificationsProvider);
    final driverLeftCount = driverLeftAsync.maybeWhen(
      data: (notifications) => notifications.length,
      orElse: () => 0,
    );

    // Combined notification count
    final totalNotificationCount = pendingCount + driverLeftCount;

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
    }); // This was the missing closing bracket

    // Listen for new driver_left notifications to show toast
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      driverLeftNotificationsProvider,
      (previous, next) {
        next.whenData((nextNotifs) {
          previous?.whenData((prevNotifs) {
            if (nextNotifs.length > prevNotifs.length) {
              // Find new notifications
              final prevIds = prevNotifs.map((n) => n['id']).toSet();
              final newNotifs = nextNotifs.where(
                (n) => !prevIds.contains(n['id']),
              );
              for (var notif in newNotifs) {
                _showDriverLeftToast(context, notif);
              }
            }
          });
        });
      },
    );

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
                      child: _buildCombinedNotificationList(
                        pendingUsersAsync,
                        driverLeftAsync,
                      ),
                    );
                  },
                );
              },
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  _buildItem(FluentIcons.ringer, '', marginRight: 8),
                  if (totalNotificationCount > 0)
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

  /// Show toast notification when a driver leaves the company
  void _showDriverLeftToast(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    final driverName = notification['data']?['driver_name'] ?? 'A driver';
    displayInfoBar(
      context,
      duration: const Duration(seconds: 10),
      alignment: Alignment.bottomRight,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Driver Left Company'),
          content: Text('$driverName has left the company.'),
          severity: InfoBarSeverity.warning,
          action: Button(
            onPressed: () {
              ref
                  .read(notificationActionsProvider)
                  .dismissNotification(notification['id']);
              close();
            },
            child: const Text('Dismiss'),
          ),
          onClose: close,
        );
      },
    );
  }

  /// Builds combined notification list with pending users and driver_left notifications
  Widget _buildCombinedNotificationList(
    AsyncValue<List<UserProfile>> pendingUsersAsync,
    AsyncValue<List<Map<String, dynamic>>> driverLeftAsync,
  ) {
    final pendingUsers = pendingUsersAsync.maybeWhen(
      data: (users) => users,
      orElse: () => <UserProfile>[],
    );
    final driverLeftNotifs = driverLeftAsync.maybeWhen(
      data: (notifs) => notifs,
      orElse: () => <Map<String, dynamic>>[],
    );

    final isEmpty = pendingUsers.isEmpty && driverLeftNotifs.isEmpty;

    if (isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No notifications'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Driver Left Section
          if (driverLeftNotifs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'DRIVER UPDATES',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...driverLeftNotifs.map((notif) {
              final driverName = notif['data']?['driver_name'] ?? 'Unknown';
              final driverEmail = notif['data']?['driver_email'] ?? '';
              return ListTile(
                title: Text(
                  driverName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (driverEmail.isNotEmpty) Text(driverEmail),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Left Company',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(FluentIcons.clear, color: Colors.grey),
                  onPressed: () {
                    ref
                        .read(notificationActionsProvider)
                        .dismissNotification(notif['id']);
                  },
                ),
              );
            }),
            if (pendingUsers.isNotEmpty) const Divider(),
          ],
          // Pending Users Section
          if (pendingUsers.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'PENDING APPROVALS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...pendingUsers.map((user) {
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
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(FluentIcons.clear, color: Colors.red),
                      onPressed: () {
                        ref
                            .read(notificationActionsProvider)
                            .rejectUser(user.id);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
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
