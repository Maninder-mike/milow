import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../../domain/models/notification_item.dart';
import '../../data/notification_provider.dart';
import '../../../../core/router/router_provider.dart';
import '../../../dispatch/presentation/providers/load_providers.dart';
import '../../../users/data/user_repository_provider.dart';
import '../../../dispatch/presentation/providers/document_providers.dart';
import '../../../dispatch/presentation/widgets/document_review_dialog.dart';

final dismissedItemsProvider =
    NotifierProvider<DismissedItemsNotifier, Set<String>>(
      DismissedItemsNotifier.new,
    );

class DismissedItemsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void add(String id) {
    state = {...state, id};
  }

  void addAll(Iterable<String> ids) {
    state = {...state, ...ids};
  }
}

final notificationsAggregatorProvider = Provider<List<NotificationItem>>((ref) {
  // Watch dismissed items
  final dismissed = ref.watch(dismissedItemsProvider);

  // Watch source providers
  final pendingUsers = ref
      .watch(pendingUsersProvider)
      .maybeWhen(data: (d) => d, orElse: () => <UserProfile>[]);

  final driverLeft = ref
      .watch(driverLeftNotificationsProvider)
      .maybeWhen(data: (d) => d, orElse: () => <Map<String, dynamic>>[]);

  final companyInvites = ref
      .watch(companyInviteNotificationsProvider)
      .maybeWhen(data: (d) => d, orElse: () => <Map<String, dynamic>>[]);

  final delayedLoads = ref
      .watch(delayedLoadsProvider)
      .maybeWhen(data: (d) => d, orElse: () => []);

  final users = ref
      .watch(usersProvider)
      .maybeWhen(data: (d) => d, orElse: () => []);

  final pendingDocs = ref
      .watch(pendingDocumentsProvider)
      .maybeWhen(data: (d) => d, orElse: () => <TripDocument>[]);

  final userMap = {for (var u in users) u.id: u};

  // Aggregate into unified list
  List<NotificationItem> items = [];

  // 1. Pending Users
  for (var user in pendingUsers) {
    final id = 'pending_user_${user.id}';
    if (dismissed.contains(id)) continue;

    items.add(
      NotificationItem(
        id: id,
        title: 'Approval Request',
        body: '${user.fullName ?? 'Unknown'} requested ${user.role.label}',
        timestamp: user.createdAt ?? DateTime.now(),
        type: NotificationType.info,
        metadata: {'user': user},
        onTap: () {
          ref.read(routerProvider).push('/users');
        },
        onDismiss: () {
          ref.read(dismissedItemsProvider.notifier).add(id);
        },
      ),
    );
  }

  // 2. Driver Left
  for (var notif in driverLeft) {
    final id = notif['id'];
    if (dismissed.contains(id)) continue;

    items.add(
      NotificationItem(
        id: id,
        title: 'Driver Left',
        body:
            '${notif['data']?['driver_name'] ?? 'Driver'} has left the company.',
        timestamp: DateTime.parse(notif['created_at']),
        type: NotificationType.warning,
        onTap: () {
          ref.read(routerProvider).push('/drivers');
        },
        onDismiss: () {
          ref.read(notificationActionsProvider).dismissNotification(id);
        },
      ),
    );
  }

  // 3. Company Invites
  for (var notif in companyInvites) {
    final id = notif['id'];
    if (dismissed.contains(id)) continue;

    final isDeclined = (notif['title'] as String? ?? '').toLowerCase().contains(
      'declined',
    );
    items.add(
      NotificationItem(
        id: id,
        title: notif['title'] ?? 'Invite Update',
        body: notif['body'] ?? notif['message'] ?? '',
        timestamp: DateTime.parse(notif['created_at']),
        type: isDeclined ? NotificationType.error : NotificationType.success,
        onTap: () {
          ref.read(routerProvider).push('/drivers');
        },
        onDismiss: () {
          ref.read(notificationActionsProvider).dismissNotification(id);
        },
      ),
    );
  }

  // 4. Delayed Loads
  for (var load in delayedLoads) {
    final id = 'delayed_load_${load.id}';
    if (dismissed.contains(id)) continue;

    final driverName = userMap[load.assignedDriverId]?.fullName ?? 'Unassigned';
    items.add(
      NotificationItem(
        id: id,
        title: 'Endangered Load #${load.tripNumber}',
        body: 'Driver: $driverName. Late since ${load.delivery.date}',
        timestamp: load.delivery.date,
        type: NotificationType.error,
        onTap: () {
          ref.read(routerProvider).push('/highway-dispatch');
        },
        onDismiss: () {
          ref.read(dismissedItemsProvider.notifier).add(id);
        },
      ),
    );
  }

  // 5. Pending Documents
  for (var doc in pendingDocs) {
    final id = 'pending_doc_${doc.id}';
    if (dismissed.contains(id)) continue;

    items.add(
      NotificationItem(
        id: id,
        title: 'Document Review Required',
        body: '${doc.documentType.label} for Trip #${doc.tripNumber ?? 'N/A'}',
        timestamp: doc.createdAt ?? DateTime.now(),
        type: NotificationType.info,
        metadata: {'document': doc},
        onTap: () {
          final context = ref
              .read(routerProvider)
              .routerDelegate
              .navigatorKey
              .currentContext;
          if (context != null) {
            showDialog(
              context: context,
              builder: (context) => DocumentReviewDialog(document: doc),
            );
          }
        },
        onDismiss: () {
          ref.read(dismissedItemsProvider.notifier).add(id);
        },
      ),
    );
  }

  // Sort: Newest First
  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return items;
});
