import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:milow_core/milow_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../notifications/data/notification_provider.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../providers/database_health_provider.dart';

class StatusBar extends ConsumerStatefulWidget {
  const StatusBar({super.key});

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar>
    with SingleTickerProviderStateMixin {
  final FlyoutController _flyoutController = FlyoutController();
  Timer? _offlineDebounceTimer;
  bool _confirmedOffline = false;
  bool _isSyncing = false;
  late AnimationController _syncAnimationController;

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _offlineDebounceTimer?.cancel();
    _flyoutController.dispose();
    _syncAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _setupListeners(context);

    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final pendingCount = pendingUsersAsync.maybeWhen(
      data: (users) => users.length,
      orElse: () => 0,
    );
    final driverLeftAsync = ref.watch(driverLeftNotificationsProvider);
    final driverLeftCount = driverLeftAsync.maybeWhen(
      data: (notifications) => notifications.length,
      orElse: () => 0,
    );
    final companyInviteAsync = ref.watch(companyInviteNotificationsProvider);
    final companyInviteCount = companyInviteAsync.maybeWhen(
      data: (notifications) => notifications.length,
      orElse: () => 0,
    );
    final totalNotificationCount =
        pendingCount + driverLeftCount + companyInviteCount;

    final connectivityAsync = ref.watch(connectivityProvider);
    final dbHealth = ref.watch(databaseHealthProvider);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F3F3),
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Row(
        children: [
          // 1. Connectivity Status
          connectivityAsync.when(
            data: (results) {
              final isOffline = results.contains(ConnectivityResult.none);
              return _buildStatusItem(
                icon: isOffline
                    ? FluentIcons.wifi_off_24_regular
                    : FluentIcons.wifi_1_24_regular,
                label: isOffline ? 'Offline' : 'Online: Stable (5G)',
                color: isOffline ? Colors.red : Colors.green,
              );
            },
            loading: () => _buildStatusItem(
              icon: FluentIcons.wifi_warning_24_regular,
              label: 'Checking...',
              color: Colors.grey,
            ),
            error: (error, stack) => _buildStatusItem(
              icon: FluentIcons.wifi_off_24_regular,
              label: 'Error',
              color: Colors.red,
            ),
          ),

          _buildDivider(),

          // 2. Database Status
          _buildStatusItem(
            icon: dbHealth.status == DatabaseStatus.connected
                ? FluentIcons.database_24_regular
                : FluentIcons.warning_24_regular,
            label: _getDbStatusLabel(dbHealth.status),
            color: _getDbStatusColor(dbHealth.status),
          ),
          _buildDivider(),

          // 3. Daily Load Completion
          Tooltip(
            message: '35 Completed\n8 Active\n2 Delayed', // TODO: Dynamic data
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Loads:',
                  style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  height: 12,
                  child: ProgressBar(
                    value: 78,
                    backgroundColor: Colors.grey.withValues(alpha: 0.3),
                    activeColor: Colors.green, // TODO: Orange if delayed > 0
                  ),
                ),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF333333),
                    ),
                    children: [
                      const TextSpan(
                        text: '35/45 ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: '• 2 Delayed',
                        style: TextStyle(
                          color: Colors.orange.darker,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 4. Sync Button with Animation + Last Sync Time
          GestureDetector(
            onTap: _performSync,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RotationTransition(
                    turns: _syncAnimationController,
                    child: Icon(
                      FluentIcons.arrow_sync_24_regular,
                      size: 14,
                      color: _isSyncing
                          ? Colors.blue
                          : Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatLastSyncTime(dbHealth.lastSyncTime),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),

          // Notifications
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
                        companyInviteAsync,
                      ),
                    );
                  },
                );
              },
              child: SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      FluentIcons.alert_24_regular,
                      size: 18,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                    if (totalNotificationCount > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF3F3F3),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setupListeners(BuildContext context) {
    ref.listen<AsyncValue<List<UserProfile>>>(pendingUsersProvider, (
      previous,
      next,
    ) {
      next.whenData((nextUsers) {
        previous?.whenData((prevUsers) {
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

    ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider, (
      previous,
      next,
    ) {
      next.whenData((results) {
        final isOffline = results.contains(ConnectivityResult.none);
        if (isOffline) {
          if (_confirmedOffline) return;
          if (_offlineDebounceTimer?.isActive ?? false) return;
          _offlineDebounceTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _showOfflineNotification(context);
              _confirmedOffline = true;
            }
          });
        } else {
          _offlineDebounceTimer?.cancel();
          if (_confirmedOffline) {
            _showOnlineNotification(context);
            _confirmedOffline = false;
          }
        }
      });
    });

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      driverLeftNotificationsProvider,
      (previous, next) {
        next.whenData((nextNotifs) {
          previous?.whenData((prevNotifs) {
            if (nextNotifs.length > prevNotifs.length) {
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
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? Colors.black.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF333333)),
        ),
      ],
    );
  }

  Future<void> _performSync() async {
    if (_isSyncing) return; // Prevent double-tap

    setState(() => _isSyncing = true);
    _syncAnimationController.repeat();

    try {
      // Refresh all data providers
      ref.invalidate(pendingUsersProvider);
      ref.invalidate(driverLeftNotificationsProvider);
      ref.invalidate(companyInviteNotificationsProvider);
      ref.invalidate(databaseHealthProvider);

      // Give a slight delay for visual feedback
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      if (mounted) {
        _syncAnimationController.stop();
        _syncAnimationController.reset();
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 1,
      height: 14,
      color: const Color(0xFFCCCCCC),
    );
  }

  String _getDbStatusLabel(DatabaseStatus status) {
    switch (status) {
      case DatabaseStatus.connected:
        return 'Database: Connected';
      case DatabaseStatus.disconnected:
        return 'Database: Disconnected';
      case DatabaseStatus.checking:
        return 'Database: Checking...';
      case DatabaseStatus.error:
        return 'Database: Error';
    }
  }

  Color _getDbStatusColor(DatabaseStatus status) {
    switch (status) {
      case DatabaseStatus.connected:
        return Colors.green;
      case DatabaseStatus.disconnected:
      case DatabaseStatus.error:
        return Colors.red;
      case DatabaseStatus.checking:
        return Colors.grey;
    }
  }

  String _formatLastSyncTime(DateTime? time) {
    if (time == null) return 'Last Sync: --:--';
    return 'Last Sync: ${_timeToString(time)}';
  }

  String _timeToString(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ---------------------------------------------------------------------------
  // Notification Widgets
  // ---------------------------------------------------------------------------

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
      duration: const Duration(seconds: 5),
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

  Widget _buildCombinedNotificationList(
    AsyncValue<List<UserProfile>> pendingUsersAsync,
    AsyncValue<List<Map<String, dynamic>>> driverLeftAsync,
    AsyncValue<List<Map<String, dynamic>>> companyInviteAsync,
  ) {
    final pendingUsers = pendingUsersAsync.maybeWhen(
      data: (users) => users,
      orElse: () => <UserProfile>[],
    );
    final driverLeftNotifs = driverLeftAsync.maybeWhen(
      data: (notifs) => notifs,
      orElse: () => <Map<String, dynamic>>[],
    );
    final companyInviteNotifs = companyInviteAsync.maybeWhen(
      data: (notifs) => notifs,
      orElse: () => <Map<String, dynamic>>[],
    );

    final isEmpty =
        pendingUsers.isEmpty &&
        driverLeftNotifs.isEmpty &&
        companyInviteNotifs.isEmpty;

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
                  icon: Icon(
                    FluentIcons.dismiss_24_regular,
                    color: Colors.grey,
                  ),
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
                      icon: Icon(
                        FluentIcons.checkmark_24_regular,
                        color: Colors.green,
                      ),
                      onPressed: () {
                        ref
                            .read(notificationActionsProvider)
                            .approveUser(user.id, user.role);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        FluentIcons.dismiss_24_regular,
                        color: Colors.red,
                      ),
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
          // Verification Response Notifications (Accepted/Declined)
          if (companyInviteNotifs.isNotEmpty) ...[
            if (pendingUsers.isNotEmpty || driverLeftNotifs.isNotEmpty)
              const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'VERIFICATION RESPONSES',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...companyInviteNotifs.map((notif) {
              final title = notif['title'] ?? 'Verification Response';
              final body = notif['body'] ?? notif['message'] ?? '';
              final driverName = notif['data']?['driver_name'] ?? 'Unknown';
              final isDeclined = title.toLowerCase().contains('declined');
              return ListTile(
                title: Text(
                  driverName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDeclined
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDeclined ? 'Declined' : 'Accepted',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDeclined ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    FluentIcons.dismiss_24_regular,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    ref
                        .read(notificationActionsProvider)
                        .dismissNotification(notif['id']);
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
