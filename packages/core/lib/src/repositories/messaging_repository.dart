import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fpdart/fpdart.dart';
import '../models/message.dart';
import '../utils/failure.dart';
import '../services/core_network_client.dart';

/// Repository for handling land-scoped and direct messaging
class MessagingRepository {
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static CoreNetworkClient _getNetworkClient(SupabaseClient client) {
    return CoreNetworkClient(client);
  }

  /// Fetches messages for a specific load
  static Future<Result<List<Message>>> getLoadMessages(
    String loadId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final result = await _getNetworkClient(client).query(() async {
      final response = await client
          .from('messages')
          .select(
            '*, sender:profiles!messages_sender_id_fkey(full_name, role, avatar_url)',
          )
          .eq('load_id', loadId)
          .order('created_at', ascending: true);
      return response;
    }, operationName: 'getLoadMessages');

    return result.fold((failure) => left(failure), (data) {
      try {
        final messages = (data as List)
            .map((json) => Message.fromJson(json))
            .toList();
        return right(messages);
      } catch (e) {
        return left(ParsingFailure(e.toString()));
      }
    });
  }

  /// Fetches all unique conversations for the current user
  static Future<Result<List<Message>>> getConversations({
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final myId = client.auth.currentUser?.id;
    if (myId == null) return left(UnauthorizedFailure('Not authenticated'));

    final result = await _getNetworkClient(client).query(() async {
      // This is a simplified approach: fetch latest messages where user is sender or receiver
      // and group them in the app. A more robust SQL view is preferred for production.
      final response = await client
          .from('messages')
          .select(
            '*, sender:profiles!messages_sender_id_fkey(full_name, role, avatar_url)',
          )
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: false);
      return response;
    }, operationName: 'getConversations');

    return result.fold((failure) => left(failure), (data) {
      try {
        final messages = (data as List)
            .map((json) => Message.fromJson(json))
            .toList();

        // Group by partner to get latest message per conversation
        final Map<String, Message> latestMessages = {};
        for (final msg in messages) {
          final partnerId = msg.senderId == myId
              ? msg.receiverId
              : msg.senderId;
          if (partnerId != null && !latestMessages.containsKey(partnerId)) {
            latestMessages[partnerId] = msg;
          }
        }

        return right(latestMessages.values.toList());
      } catch (e) {
        return left(ParsingFailure(e.toString()));
      }
    });
  }

  /// Fetches messages for a direct conversation
  static Future<Result<List<Message>>> getDirectMessages(
    String partnerId, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final myId = client.auth.currentUser?.id;
    if (myId == null) return left(UnauthorizedFailure('Not authenticated'));

    final result = await _getNetworkClient(client).query(() async {
      final response = await client
          .from('messages')
          .select(
            '*, sender:profiles!messages_sender_id_fkey(full_name, role, avatar_url)',
          )
          .or(
            'and(sender_id.eq.$myId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$myId)',
          )
          .order('created_at', ascending: true);
      return response;
    }, operationName: 'getDirectMessages');

    return result.fold((failure) => left(failure), (data) {
      try {
        final messages = (data as List)
            .map((json) => Message.fromJson(json))
            .toList();
        return right(messages);
      } catch (e) {
        return left(ParsingFailure(e.toString()));
      }
    });
  }

  /// Sends a message, optionally scoped to a load
  static Future<Result<Message>> sendMessage({
    required String content,
    String? loadId,
    String? receiverId,
    MessageType type = MessageType.text,
    String? attachmentUrl,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final user = client.auth.currentUser;

    if (user == null) {
      return left(UnauthorizedFailure('User not authenticated'));
    }

    final messageData = {
      'sender_id': user.id,
      'content': content,
      'message_type': type.value,
      'load_id': loadId,
      'receiver_id': receiverId,
      'attachment_url': attachmentUrl,
    };

    final result = await _getNetworkClient(client).query(() async {
      final response = await client
          .from('messages')
          .insert(messageData)
          .select(
            '*, sender:profiles!messages_sender_id_fkey(full_name, role, avatar_url)',
          )
          .single();
      return response;
    }, operationName: 'sendMessage');

    return result.fold((failure) => left(failure), (data) {
      try {
        return right(Message.fromJson(data));
      } catch (e) {
        return left(ParsingFailure(e.toString()));
      }
    });
  }

  /// Streams messages for a specific load
  static Stream<List<Message>> subscribeToLoadMessages(
    String loadId, {
    SupabaseClient? supabaseClient,
  }) {
    final client = _getClient(supabaseClient);
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('load_id', loadId)
        .order('created_at', ascending: true)
        .map((data) => data.map((json) => Message.fromJson(json)).toList());
  }

  /// Streams messages for a direct conversation
  static Stream<List<Message>> subscribeToDirectMessages(
    String partnerId, {
    SupabaseClient? supabaseClient,
  }) {
    final client = _getClient(supabaseClient);
    final myId = client.auth.currentUser?.id;
    if (myId == null) return Stream.value([]);

    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map(
          (data) => data
              .map((json) => Message.fromJson(json))
              .where(
                (msg) =>
                    (msg.senderId == myId && msg.receiverId == partnerId) ||
                    (msg.senderId == partnerId && msg.receiverId == myId),
              )
              .toList(),
        );
  }
}
