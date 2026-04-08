import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:milow/features/offline/data/database/driver_database.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
        _listenToLocalMessages();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _localSubscription?.cancel();
        _inbox = [];
        notifyListeners();
      }
    });
  }

  Future<void> init() async {
    _listenToLocalMessages();
  }

  StreamSubscription? _localSubscription;

  void _listenToLocalMessages() {
    _localSubscription?.cancel();
    _localSubscription = watchMessages().listen((messages) {
      _inbox = messages;
      notifyListeners();
    });
  }

  /// Watch all messages (reactive)
  Stream<List<Message>> watchMessages() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return Stream.value([]);

    // Drift-based watch for Messages table
    return _db.select(_db.messages).watch().map((rows) {
      return rows.map((row) => _fromData(row)).toList();
    });
  }

  static Message _fromData(MessageData data) {
    return Message(
      id: data.id,
      companyId: data.companyId,
      loadId: data.loadId,
      senderId: data.senderId,
      receiverId: data.receiverId,
      content: data.content,
      type: MessageType.fromValue(data.messageType),
      attachmentUrl: data.attachmentUrl,
      createdAt: data.createdAt,
      senderName: data.senderName,
      senderRole: data.senderRole,
      senderAvatarUrl: data.senderAvatarUrl,
    );
  }


  Future<void> _saveToLocal(Message message, {bool isSynced = false}) async {
    final data = MessageData(
      id: message.id ?? const Uuid().v4(),
      companyId: message.companyId,
      loadId: message.loadId,
      senderId: message.senderId,
      receiverId: message.receiverId,
      content: message.content,
      messageType: message.type.value,
      attachmentUrl: message.attachmentUrl,
      createdAt: message.createdAt,
      senderName: message.senderName,
      senderRole: message.senderRole,
      senderAvatarUrl: message.senderAvatarUrl,
      isSynced: isSynced,
    );

    await _db.into(_db.messages).insertOnConflictUpdate(data);
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
          _db.transaction(() async {
            await (_db.delete(_db.messages)..where((m) => m.id.equals(message.id!))).go();
            await _saveToLocal(syncedMessage, isSynced: true);
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _localSubscription?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
