import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:milow_core/milow_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../notifications/data/notification_provider.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../providers/database_health_provider.dart';
import 'package:terminal/core/constants/app_elevation.dart';
import '../../../../core/constants/app_colors.dart';

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

    final theme = FluentTheme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final backgroundColor = isLight
        ? theme.resources.solidBackgroundFillColorSecondary
        : theme.resources.solidBackgroundFillColorBase;
    final borderColor = theme.resources.dividerStrokeColorDefault;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // 1. Connectivity Status
          connectivityAsync.when(
            data: (results) {
              final isOffline = results.contains(ConnectivityResult.none);
              return _buildStatusItem(
                icon: Icon(
                  isOffline
                      ? FluentIcons.wifi_off_24_regular
                      : FluentIcons.wifi_1_24_regular,
                ),
                label: isOffline ? 'Offline' : 'Online',
                color: isOffline ? AppColors.error : AppColors.success,
              );
            },
            loading: () => _buildStatusItem(
              icon: const Icon(FluentIcons.wifi_warning_24_regular),
              label: 'Checking...',
              color: AppColors.neutral,
            ),
            error: (error, stack) => _buildStatusItem(
              icon: const Icon(FluentIcons.wifi_off_24_regular),
              label: 'Error',
              color: AppColors.error,
            ),
          ),

          _buildDivider(),

          // 2. Database Status
          _buildStatusItem(
            icon: dbHealth.isSyncing
                ? RotationTransition(
                    turns: _syncAnimationController,
                    child: const Icon(FluentIcons.arrow_sync_24_regular),
                  )
                : Icon(
                    dbHealth.status == DatabaseStatus.connected
                        ? FluentIcons.database_24_regular
                        : FluentIcons.warning_24_regular,
                  ),
            label: dbHealth.isSyncing
                ? 'Syncing...'
                : _getDbStatusLabel(dbHealth.status),
            color: dbHealth.isSyncing
                ? theme.accentColor
                : _getDbStatusColor(dbHealth.status),
          ),
          _buildDivider(),

          // 3. Daily Load Completion
          Builder(
            builder: (context) {
              // TODO: Replace with dynamic data from provider
              const completedLoads = 35;
              const totalLoads = 45;
              const delayedCount = 2;

              return Tooltip(
                message:
                    '$completedLoads Completed\n${totalLoads - completedLoads - delayedCount} Active\n$delayedCount Delayed',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Loads:',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      height: 12,
                      child: ProgressBar(
                        value: (completedLoads / totalLoads) * 100,
                        backgroundColor: isLight
                            ? Colors.grey.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                        activeColor: delayedCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: theme.resources.textFillColorPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: '$completedLoads/$totalLoads ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (delayedCount > 0)
                            TextSpan(
                              text: '• $delayedCount Delayed',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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
                          ? theme.accentColor
                          : theme.resources.textFillColorSecondary.withValues(
                              alpha: 0.6,
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatLastSyncTime(dbHealth.lastSyncTime),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: theme.resources.textFillColorSecondary,
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
                      padding: EdgeInsets.zero,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: AppElevation.shadow8(context),
                        ),
                        child: _buildCombinedNotificationList(
                          pendingUsersAsync,
                          driverLeftAsync,
                          companyInviteAsync,
                        ),
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
                      color: theme.resources.textFillColorPrimary.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    if (totalNotificationCount > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isLight
                                  ? theme
                                        .resources
                                        .solidBackgroundFillColorSecondary
                                  : theme
                                        .resources
                                        .solidBackgroundFillColorBase,
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
    required Widget icon,
    required String label,
    Color? color,
  }) {
    final theme = FluentTheme.of(context);
    final defaultColor = theme.resources.textFillColorSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme(
          data: IconThemeData(size: 14, color: color ?? defaultColor),
          child: icon,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: color ?? theme.resources.textFillColorPrimary,
          ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 1,
      height: 12,
      color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
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
        return AppColors.success;
      case DatabaseStatus.disconnected:
      case DatabaseStatus.error:
        return AppColors.error;
      case DatabaseStatus.checking:
        return AppColors.neutral;
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

    final theme = FluentTheme.of(context);

    final isEmpty =
        pendingUsers.isEmpty &&
        driverLeftNotifs.isEmpty &&
        companyInviteNotifs.isEmpty;

    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No notifications',
          style: TextStyle(color: theme.resources.textFillColorSecondary),
        ),
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
                        color: AppColors.warning.withValues(alpha: 0.1),
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
                    color: theme.resources.textFillColorSecondary,
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
                        color: AppColors.info.withValues(alpha: 0.1),
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
                        color: AppColors.success,
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
                        color: AppColors.error,
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
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDeclined ? 'Declined' : 'Accepted',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDeclined
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    FluentIcons.dismiss_24_regular,
                    color: theme.resources.textFillColorSecondary,
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
