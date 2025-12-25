import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification types
enum NotificationType { reminder, company, news, message }

/// Data Class for Notification
class ServiceNotificationItem {
  final String title;
  final String body;
  final NotificationType type;

  ServiceNotificationItem({
    required this.title,
    required this.body,
    required this.type,
  });

  static ServiceNotificationItem fromPayload(Map<String, dynamic> payload) {
    final typeStr = payload['type'] as String?;
    NotificationType type;
    if (typeStr == 'reminder') {
      type = NotificationType.reminder;
    } else if (typeStr == 'company' || typeStr == 'company_invite') {
      type = NotificationType.company;
    } else if (typeStr == 'message') {
      type = NotificationType.message;
    } else {
      type = NotificationType.news;
    }

    return ServiceNotificationItem(
      title: payload['title'] ?? 'Notification',
      body: payload['body'] ?? payload['message'] ?? '',
      type: type,
    );
  }
}

/// Service to manage notifications and provide unread count across the app
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Stream controller for unread count
  final _countController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _countController.stream;

  /// Stream controller for incoming notifications (to show toast/snackbar)
  final _incomingController =
      StreamController<ServiceNotificationItem>.broadcast();
  Stream<ServiceNotificationItem> get incomingStream =>
      _incomingController.stream;

  /// Current unread count
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  // Realtime subscription handle
  RealtimeChannel? _subscription;

  /// Initialize the service
  Future<void> init() async {
    await refreshUnreadCount();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Avoid duplicate subscriptions
    if (_subscription != null) return;

    _subscription = Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // Handle INSERT specifically to broadcast event
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newRecord = payload.newRecord;

              _incomingController.add(
                ServiceNotificationItem.fromPayload(newRecord),
              );
            }
            // Always refresh count on any change (insert/update/delete)
            refreshUnreadCount();
          },
        )
        .subscribe();
  }

  /// Refresh the unread notification count from Supabase
  Future<int> refreshUnreadCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _unreadCount = 0;
        _countController.add(0);
        return 0;
      }

      final response = await Supabase.instance.client
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('is_read', false);

      _unreadCount = response;
      _countController.add(_unreadCount);
      return _unreadCount;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Add a new notification
  Future<void> addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.reminder,
  }) async {
    try {
      debugPrint('🔔 Adding notification: $title');
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'type': type.toString().split('.').last,
        'title': title,
        'body': message, // mapped to 'body' in DB
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('🔔 Error adding notification: $e');
    }
  }

  /// Add a reminder for missing end odometer
  Future<void> addMissingOdometerReminder({
    required String tripNumber,
    required String truckNumber,
  }) async {
    await addNotification(
      title: 'Missing End Odometer',
      message:
          'Trip #$tripNumber ($truckNumber) is missing the end odometer reading. Please update it to track your mileage accurately.',
      type: NotificationType.reminder,
    );
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      await refreshUnreadCount();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Check if there are any unread notifications
  bool get hasUnreadNotifications => _unreadCount > 0;

  /// Dispose the service
  void dispose() {
    _countController.close();
    _incomingController.close();
    _subscription?.unsubscribe();
  }
}

/// Global shortcut for the notification service
NotificationService get notificationService => NotificationService.instance;
