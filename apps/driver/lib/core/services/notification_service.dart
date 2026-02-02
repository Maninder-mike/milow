import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:milow/core/services/logging_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NotificationType { reminder, company, news, message }

class ServiceNotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;

  ServiceNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  unawaited(
    logger.info('FCM', 'Handling a background message: ${message.messageId}'),
  );
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _currentUnreadCount = 0;

  // Streams for compatibility with Dashboard/Settings
  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int get unreadCount => _currentUnreadCount;

  final _incomingController =
      StreamController<ServiceNotificationItem>.broadcast();
  Stream<ServiceNotificationItem> get incomingStream =>
      _incomingController.stream;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Request Permission (iOS/Android 13+)
    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      unawaited(logger.info('FCM', 'User granted permission'));
    }

    // 2. Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        logger.info('Notification', 'Notification clicked: ${details.payload}');
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    const AndroidNotificationChannel geofenceChannel =
        AndroidNotificationChannel(
          'geofence_channel',
          'Arrival Alerts',
          description: 'Notifications when arriving at trip locations.',
          importance: Importance.high,
        );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(geofenceChannel);

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      logger.info('FCM', 'Got a message whilst in the foreground!');

      final RemoteNotification? notification = message.notification;
      final AndroidNotification? android = message.notification?.android;

      if (notification != null && !kIsWeb) {
        // Show Local Notification
        unawaited(
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android?.smallIcon,
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            payload: message.data.toString(),
          ),
        );

        // Emit to incoming stream for UI updates
        _incomingController.add(
          ServiceNotificationItem(
            id: message.messageId ?? DateTime.now().toIso8601String(),
            type: _parseType(message.data['type']),
            title: notification.title ?? '',
            body: notification.body ?? '',
            data: message.data,
          ),
        );

        // Refresh count
        unawaited(refreshUnreadCount());
      }
    });

    // 4. Handle Background Messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Initial unread count
    unawaited(refreshUnreadCount());

    _initialized = true;
  }

  Future<void> refreshUnreadCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _currentUnreadCount = 0;
      _unreadCountController.add(0);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      _currentUnreadCount = response.length;
      _unreadCountController.add(_currentUnreadCount);
    } catch (e) {
      unawaited(
        logger.error('FCM', 'Failed to refresh unread count', error: e),
      );
    }
  }

  /// Adds a local notification reminder for missing end odometer
  Future<void> addMissingOdometerReminder({
    required String tripNumber,
    required String truckNumber,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          channelDescription: 'Important reminders for drivers',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: 0,
      title: 'Missing End Odometer',
      body:
          'Trip #$tripNumber (Truck #$truckNumber) is missing an end odometer reading.',
      notificationDetails: details,
    );

    // Also record it in the database so it shows up in history
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      unawaited(
        Supabase.instance.client.from('notifications').insert({
          'user_id': user.id,
          'type': 'reminder',
          'title': 'Missing End Odometer',
          'body':
              'Trip #$tripNumber (Truck #$truckNumber) is missing an end odometer reading.',
          'data': {'trip_number': tripNumber, 'truck_number': truckNumber},
          'is_read': false,
        }),
      );
      unawaited(refreshUnreadCount());
    }
  }

  /// Shows a local notification when driver arrives at a trip location
  Future<void> showArrivalNotification({
    required String locationType, // 'Pickup' or 'Delivery'
    required String locationName,
    required String tripNumber,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'geofence_channel',
          'Arrival Alerts',
          channelDescription: 'Notifications when arriving at trip locations',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Arrived at $locationType',
      body: '$locationName\nTrip #$tripNumber',
      notificationDetails: details,
    );
  }

  NotificationType _parseType(String? type) {
    switch (type) {
      case 'reminder':
        return NotificationType.reminder;
      case 'company':
        return NotificationType.company;
      case 'message':
        return NotificationType.message;
      default:
        return NotificationType.news;
    }
  }

  Future<String?> getToken() async {
    try {
      final String? token = await _fcm.getToken();
      return token;
    } catch (e) {
      unawaited(logger.error('FCM', 'Failed to get token', error: e));
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  void dispose() {
    _unreadCountController.close();
    _incomingController.close();
  }
}

final notificationService = NotificationService.instance;
