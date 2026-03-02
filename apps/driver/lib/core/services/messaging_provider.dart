import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:milow/core/services/notification_service.dart';

class MessagingProvider extends ChangeNotifier {
  final DriverDatabase _db;
  final SupabaseClient _supabase;

  List<Message> _inbox = [];
  List<Message> get inbox => _inbox;

  final bool _isLoading = false;
  bool get isLoading => _isLoading;

  StreamSubscription? _realtimeSubscription;

  MessagingProvider(this._db, {SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client {
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      debugPrint('🔗 MessagingProvider Auth Event: ${data.event}');
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _subscribeToRealtime();
        loadLocalMessages();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _realtimeSubscription?.cancel();
        _inbox = [];
        notifyListeners();
      }
    });
  }

  Future<void> init() async {
    await loadLocalMessages();
    _subscribeToRealtime();
  }

  Future<void> loadLocalMessages() async {
    try {
      // Use customSelect since we are bypassing code generation for Messages
      final rows = await _db
          .customSelect('SELECT * FROM messages ORDER BY created_at DESC')
          .get();

      _inbox = rows.map((row) {
        return Message(
          id: row.read<String>('id'),
          companyId: row.read<String?>('company_id'),
          loadId: row.read<String?>('load_id'),
          senderId: row.read<String>('sender_id'),
          receiverId: row.read<String?>('receiver_id'),
          content: row.read<String>('content'),
          type: MessageType.fromValue(row.read<String>('message_type')),
          attachmentUrl: row.read<String?>('attachment_url'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('created_at') * 1000,
          ),
          senderName: row.read<String?>('sender_name'),
          senderRole: row.read<String?>('sender_role'),
          senderAvatarUrl: row.read<String?>('sender_avatar_url'),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local messages: $e');
    }
  }

  void _subscribeToRealtime() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    _realtimeSubscription?.cancel();
    _realtimeSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((data) async {
          debugPrint(
            '📥 Realtime message update received: ${data.length} messages',
          );
          for (final json in data) {
            try {
              final message = Message.fromJson(json);
              // Only save if it's relevant to me
              if (message.senderId == myId ||
                  message.receiverId == myId ||
                  message.loadId != null) {
                final isNew = !inbox.any((m) => m.id == message.id);
                await _saveToLocal(message, isSynced: true);

                // Trigger local notification if it's a new message from someone else
                if (isNew && message.senderId != myId) {
                  unawaited(
                    notificationService.showNotification(
                      id: message.id.hashCode,
                      title:
                          'New Message from ${message.senderName ?? 'Someone'}',
                      body: message.content,
                      payload: {
                        'type': 'new_message',
                        'loadId': message.loadId,
                      }.toString(),
                      type: NotificationType.message,
                    ),
                  );
                }
              }
            } catch (e) {
              debugPrint('Error parsing realtime message: $e');
            }
          }
          await loadLocalMessages();
        });
  }

  Future<void> _saveToLocal(Message message, {bool isSynced = false}) async {
    final timestamp = message.createdAt.millisecondsSinceEpoch ~/ 1000;
    await _db.customInsert(
      'INSERT OR REPLACE INTO messages '
      '(id, company_id, load_id, sender_id, receiver_id, content, message_type, attachment_url, created_at, sender_name, sender_role, sender_avatar_url, is_synced) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable(message.id ?? const Uuid().v4()),
        Variable(message.companyId),
        Variable(message.loadId),
        Variable(message.senderId),
        Variable(message.receiverId),
        Variable(message.content),
        Variable(message.type.value),
        Variable(message.attachmentUrl),
        Variable(timestamp),
        Variable(message.senderName),
        Variable(message.senderRole),
        Variable(message.senderAvatarUrl),
        Variable(isSynced),
      ],
    );
  }

  Future<void> sendMessage({
    required String content,
    String? loadId,
    String? receiverId,
  }) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    final message = Message(
      id: const Uuid().v4(),
      companyId: null, // Will be filled by backend
      senderId: myId,
      receiverId: receiverId,
      loadId: loadId,
      content: content,
      createdAt: DateTime.now(),
      senderName: 'You',
    );

    // 1. Save locally (Optimistic UI)
    await _saveToLocal(message, isSynced: false);
    await loadLocalMessages();

    // 2. Sync to Supabase
    final result = await MessagingRepository.sendMessage(
      content: content,
      loadId: loadId,
      receiverId: receiverId,
      supabaseClient: _supabase,
    );

    result.fold(
      (failure) {
        debugPrint('❌ Message sync failed: ${failure.message}');
        // Optional: Notify user or update message status to "failed"
      },
      (syncedMessage) {
        debugPrint('✅ Message synced: ${syncedMessage.id}');
        // 3. Update local as synced and with actual ID/data from server
        // We use the temporary ID to find and replace it
        unawaited(
          _db
              .customStatement('DELETE FROM messages WHERE id = ?', [
                message.id,
              ])
              .then((_) async {
                await _saveToLocal(syncedMessage, isSynced: true);
                await loadLocalMessages();
              }),
        );
      },
    );
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
