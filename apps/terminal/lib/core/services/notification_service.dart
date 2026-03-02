import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

@riverpod
class NotificationList extends _$NotificationList {
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

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

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
        if (kDebugMode) {
          debugPrint(
            'User granted permission: ${settings.authorizationStatus}',
          );
        }

        // Listen to foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (kDebugMode) {
            debugPrint('Got a message whilst in the foreground!');
            debugPrint('Message data: ${message.data}');
          }

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
        if (kDebugMode) {
          debugPrint('FCM Init failed: $e');
        }
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
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}

@riverpod
class SystemNotificationNotifier extends _$SystemNotificationNotifier {
  RealtimeChannel? _subscription;

  @override
  Future<void> build() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null) {
      // 1. Fetch user's company_id first
      String? companyId;
      try {
        final profile = await client
            .from('profiles')
            .select('company_id')
            .eq('id', user.id)
            .maybeSingle();
        companyId = profile?['company_id'] as String?;
      } catch (e) {
        if (kDebugMode) debugPrint('Error fetching user company_id: $e');
      }

      // 2. Fetch history (messages in company or directed to user)
      try {
        final query = client.from('messages').select();

        final filterQuery = (companyId != null)
            ? query.eq('company_id', companyId)
            : query.eq('receiver_id', user.id);

        final data = await filterQuery
            .order('created_at', ascending: false)
            .limit(20);

        final notifications = data.map((record) {
          final content = record['content'] as String;
          return AppNotification(
            id: record['id'].hashCode,
            title: 'Message',
            body: content,
            timestamp: DateTime.parse(record['created_at']),
            isRead: true,
          );
        }).toList();

        for (final n in notifications.reversed) {
          ref.read(notificationListProvider.notifier).add(n);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error fetching notification history: $e');
        }
      }

      _subscribeToMessages(user.id, companyId);
    }
  }

  void _subscribeToMessages(String userId, String? companyId) {
    if (_subscription != null) return;

    final client = Supabase.instance.client;
    var channel = client.channel('public:messages');

    if (companyId != null) {
      // Listen to all messages in company
      _subscription = channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'company_id',
              value: companyId,
            ),
            callback: (payload) => _handleNewMessage(payload.newRecord, userId),
          )
          .subscribe();
    } else {
      // Fallback to direct messages only
      _subscription = channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: userId,
            ),
            callback: (payload) => _handleNewMessage(payload.newRecord, userId),
          )
          .subscribe();
    }
  }

  Future<void> _handleNewMessage(
    Map<String, dynamic> record,
    String currentUserId,
  ) async {
    try {
      final senderId = record['sender_id'] as String;

      // 1. Ignore if sent by self
      if (senderId == currentUserId) return;

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) return;

      final content = record['content'] as String;
      final loadId = record['load_id'] as String?;

      // 2. Fetch sender name
      final senderData = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', senderId)
          .maybeSingle();

      final senderName = senderData?['full_name'] as String? ?? 'Someone';
      final contextLabel = loadId != null ? ' (Load Message)' : '';
      final title = 'Message from $senderName$contextLabel';

      // 3. Show Toast
      await NotificationService().showNotification(
        id: record['id'].hashCode,
        title: title,
        body: content,
      );

      // 4. Add to Bell List
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
      if (kDebugMode) {
        debugPrint('Error showing notification: $e');
      }
    }
  }

  Future<void> stop() async {
    if (_subscription != null) {
      await Supabase.instance.client.removeChannel(_subscription!);
      _subscription = null;
    }
  }
}
