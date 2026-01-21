import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

part 'notification_service.g.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

/// Simple model for UI display
class AppNotification {
  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}

/// Provider to hold the list of notifications for the Bell Icon
final notificationListProvider =
    NotifierProvider<NotificationListNotifier, List<AppNotification>>(
      NotificationListNotifier.new,
    );

class NotificationListNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [];

  void add(AppNotification notification) {
    state = [notification, ...state];
  }

  void markAsRead(int id) {
    state = [
      for (final n in state)
        if (n.id == id)
          AppNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            timestamp: n.timestamp,
            isRead: true,
          )
        else
          n,
    ];
  }

  void clearAll() {
    state = [];
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Local Notifications (for toasts)
    const DarwinInitializationSettings initializationSettingsMacOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(macOS: initializationSettingsMacOS);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 2. Initialize FCM (macOS/Android/iOS only)
    if (!Platform.isWindows) {
      try {
        final messaging = FirebaseMessaging.instance;

        // Request permission
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('User granted permission: ${settings.authorizationStatus}');

        // Listen to foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');

          if (message.notification != null) {
            final notification = message.notification!;
            // Show local toast
            showNotification(
              id: notification.hashCode,
              title: notification.title ?? 'New Notification',
              body: notification.body ?? '',
            );
            // Add to Notification Center (Bell)
            // Note: We need a way to access the provider container or use a callback.
            // For simplicity in this singleton, we rely on the Riverpod notifier listening to streams,
            // OR we can expose a global stream.
            // Ideally, the SystemNotificationNotifier should handle this.
          }
        });
      } catch (e) {
        debugPrint('FCM Init failed: $e');
      }
    }

    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const DarwinNotificationDetails macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      macOS: macOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}

@riverpod
class SystemNotificationNotifier extends _$SystemNotificationNotifier {
  RealtimeChannel? _subscription;

  @override
  Future<void> build() async {
    // 1. Listen to Supabase (Realtime) - Works on ALL platforms including Windows
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Fetch history first
      try {
        final data = await Supabase.instance.client
            .from('messages')
            .select()
            .eq('receiver_id', user.id)
            .order('created_at', ascending: false)
            .limit(20);

        final notifications = data.map((record) {
          final content = record['content'] as String;
          // Ideally fetch sender name here or just show generic
          return AppNotification(
            id: record['id'].hashCode,
            title: 'Message', // Placeholder until we join
            body: content,
            timestamp: DateTime.parse(record['created_at']),
            isRead:
                true, // Assume history is read? Or check 'read_at'? Table 'messages' might not have it.
          );
        }).toList();

        // Update list
        // Note: This is an async build, but notificationListProvider is separate.
        // We push to the separate provider.
        for (final n in notifications.reversed) {
          ref.read(notificationListProvider.notifier).add(n);
        }
      } catch (e) {
        debugPrint('Error fetching notification history: $e');
      }

      _subscribeToMessages(user.id);
    }

    // 2. Listen to FCM (macOS only) - Integrated via main init,
    // but here we could potentially listen to token refresh etc.
  }

  void _subscribeToMessages(String userId) {
    if (_subscription != null) return;

    _subscription = Supabase.instance.client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            _handleNewMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  Future<void> _handleNewMessage(Map<String, dynamic> record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) return;

      final senderId = record['sender_id'] as String;
      final content = record['content'] as String;

      // Fetch sender name
      final senderData = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', senderId)
          .maybeSingle();

      final senderName = senderData?['full_name'] as String? ?? 'Someone';
      final title = 'New Message from $senderName';

      // 1. Show Toast
      await NotificationService().showNotification(
        id: record['id'].hashCode,
        title: title,
        body: content,
      );

      // 2. Add to Bell List (Source of Truth)
      // Accessing the provider via ref (available in Riverpod class)
      ref
          .read(notificationListProvider.notifier)
          .add(
            AppNotification(
              id: record['id'].hashCode,
              title: title,
              body: content,
              timestamp: DateTime.now(),
            ),
          );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> stop() async {
    if (_subscription != null) {
      await Supabase.instance.client.removeChannel(_subscription!);
      _subscription = null;
    }
  }
}
