import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_service.g.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const DarwinInitializationSettings initializationSettingsMacOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(macOS: initializationSettingsMacOS);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
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
    // Only initialize if user is logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Check if notifications are enabled from settings?
      // For now, assume enabled or check shared preferences if implemented globally
      // actually settings page has a state, but it's local state.
      // Ideally should be in a provider.
      _subscribeToMessages(user.id);
    }
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

      await NotificationService().showNotification(
        id: record['id'].hashCode,
        title: 'New Message from $senderName',
        body: content,
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
