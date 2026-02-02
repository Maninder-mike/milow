import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:milow_core/milow_core.dart';
import '../../../dispatch/domain/models/load.dart';
import '../../../dispatch/presentation/providers/load_providers.dart';
import '../../../notifications/data/notification_provider.dart';
import '../../../users/data/user_repository_provider.dart';
import '../../../../core/constants/app_colors.dart';

class NotificationFlyoutContent extends ConsumerWidget {
  const NotificationFlyoutContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    // Watch providers once at the top level
    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final driverLeftAsync = ref.watch(driverLeftNotificationsProvider);
    final companyInviteAsync = ref.watch(companyInviteNotificationsProvider);
    final delayedLoadsAsync = ref.watch(delayedLoadsProvider);
    final usersAsync = ref.watch(usersProvider);

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
    final delayedLoads = delayedLoadsAsync.maybeWhen(
      data: (loads) => loads,
      orElse: () => <Load>[],
    );

    final isEmpty =
        pendingUsers.isEmpty &&
        driverLeftNotifs.isEmpty &&
        companyInviteNotifs.isEmpty &&
        delayedLoads.isEmpty;

    if (isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          'No notifications',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Driver Updates
            if (driverLeftNotifs.isNotEmpty) ...[
              _buildSectionHeader('DRIVER UPDATES'),
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

            // Pending Approvals
            if (pendingUsers.isNotEmpty) ...[
              _buildSectionHeader('PENDING APPROVALS'),
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

            // Verification Responses
            if (companyInviteNotifs.isNotEmpty) ...[
              if (pendingUsers.isNotEmpty || driverLeftNotifs.isNotEmpty)
                const Divider(),
              _buildSectionHeader('VERIFICATION RESPONSES'),
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

            // Delayed Loads
            if (delayedLoads.isNotEmpty) ...[
              if (pendingUsers.isNotEmpty ||
                  driverLeftNotifs.isNotEmpty ||
                  companyInviteNotifs.isNotEmpty)
                const Divider(),
              _buildSectionHeader('DELAYED LOADS', color: AppColors.error),
              // Use cached users map for O(1) lookup
              Builder(
                builder: (context) {
                  final userMap = usersAsync.maybeWhen(
                    data: (users) => {for (var u in users) u.id: u},
                    orElse: () => <String, UserProfile>{},
                  );

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: delayedLoads.map((load) {
                      final driver = userMap[load.assignedDriverId];
                      final driverName = driver?.fullName ?? 'Unassigned';

                      return ListTile(
                        title: Text(
                          'Trip #${load.tripNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Driver: $driverName',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Late since: ${DateFormat('MM/dd HH:mm').format(load.delivery.date)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close flyout
                          ref
                              .read(loadDraftProvider.notifier)
                              .update((_) => load);
                          ref
                              .read(isCreatingLoadProvider.notifier)
                              .toggle(true);
                          context.go('/highway-dispatch');
                        },
                        trailing: IconButton(
                          icon: const Icon(FluentIcons.dismiss_20_regular),
                          onPressed: () {
                            ref
                                .read(dismissedDelayedLoadIdsProvider.notifier)
                                .dismiss(load.id);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}
