import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import '../../../../core/providers/network_provider.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(coreNetworkClientProvider));
});

class MessageRepository {
  final CoreNetworkClient _client;

  MessageRepository(this._client);

  /// Send a direct message to a user
  Future<Result<void>> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    return _client.query<void>(() async {
      await _client.supabase.from('messages').insert({
        'sender_id': _client.supabase.auth.currentUser!.id,
        'receiver_id': receiverId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });
    }, operationName: 'sendMessage');
  }

  /// Fetch messages for the current user (inbox)
  Future<Result<List<Map<String, dynamic>>>> fetchMessages() async {
    return _client.query<List<Map<String, dynamic>>>(() async {
      final userId = _client.supabase.auth.currentUser!.id;
      final response = await _client.supabase
          .from('messages')
          .select(
            '*, sender:profiles!messages_sender_id_fkey(full_name, email)',
          )
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    }, operationName: 'fetchMessages');
  }
}
