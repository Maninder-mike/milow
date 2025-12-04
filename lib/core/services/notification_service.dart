import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        // If no notifications stored yet, assume there are unread notifications
        // (initial mock data has some unread)
        _unreadCount = 4; // Default unread count for first-time users
      }

      _notificationController.add(_unreadCount);
      return _unreadCount;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
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
