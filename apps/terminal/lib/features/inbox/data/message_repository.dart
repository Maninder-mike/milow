import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(Supabase.instance.client);
});

class MessageRepository {
  final SupabaseClient _supabase;

  MessageRepository(this._supabase);

  /// Send a direct message to a user
  Future<void> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    await _supabase.from('messages').insert({
      'sender_id': _supabase.auth.currentUser!.id,
      'receiver_id': receiverId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Fetch messages for the current user (inbox)
  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final userId = _supabase.auth.currentUser!.id;
    return await _supabase
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_fkey(full_name, email)')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);
  }
}
