import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification types
enum NotificationType { reminder, company, news }

/// Service to manage notifications and provide unread count across the app
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Stream controller for notification updates
  final _notificationController = StreamController<int>.broadcast();

  /// Stream of unread notification count
  Stream<int> get unreadCountStream => _notificationController.stream;

  /// Current unread count
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// Initialize the service
  Future<void> init() async {
    await refreshUnreadCount();
  }

  /// Refresh the unread notification count from SharedPreferences
  Future<int> refreshUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString('notifications');

      if (notificationsJson != null) {
        final List<dynamic> decoded = jsonDecode(notificationsJson);
        _unreadCount = decoded.where((n) => n['isRead'] == false).length;
      } else {
        // No notifications stored yet, start with 0
        _unreadCount = 0;
      }

      _notificationController.add(_unreadCount);
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
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString('notifications');

      List<dynamic> notifications = [];
      if (notificationsJson != null) {
        notifications = jsonDecode(notificationsJson);
      }

      // Generate unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Add new notification at the beginning
      notifications.insert(0, {
        'id': id,
        'type': type.toString().split('.').last,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      });

      await prefs.setString('notifications', jsonEncode(notifications));
      debugPrint('🔔 Notification saved to SharedPreferences');

      await refreshUnreadCount();
      debugPrint('🔔 Unread count refreshed: $_unreadCount');
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
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString('notifications');

      if (notificationsJson != null) {
        final List<dynamic> decoded = jsonDecode(notificationsJson);
        for (var notification in decoded) {
          notification['isRead'] = true;
        }
        await prefs.setString('notifications', jsonEncode(decoded));
        _unreadCount = 0;
        _notificationController.add(_unreadCount);
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Check if there are any unread notifications
  bool get hasUnreadNotifications => _unreadCount > 0;

  /// Dispose the service
  void dispose() {
    _notificationController.close();
  }
}

/// Global shortcut for the notification service
NotificationService get notificationService => NotificationService.instance;
