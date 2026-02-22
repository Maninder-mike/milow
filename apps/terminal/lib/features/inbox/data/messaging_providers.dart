import 'package:milow_core/milow_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:terminal/core/providers/network_provider.dart';

// Manual Notifier and Providers to bypass build_runner issues.
// This follows the same logic as the generated providers.

class SelectedChatNotifier extends Notifier<(String?, String?)> {
  @override
  (String?, String?) build() => (null, null);

  void select({String? partnerId, String? loadId}) {
    state = (partnerId, loadId);
  }
}

final selectedChatProvider =
    NotifierProvider<SelectedChatNotifier, (String?, String?)>(() {
      return SelectedChatNotifier();
    });

final allMessagesProvider = StreamProvider<List<Message>>((ref) {
  final client = ref.watch(coreNetworkClientProvider).supabase;
  return client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true)
      .map((data) => data.map((json) => Message.fromJson(json)).toList());
});

final conversationsProvider = Provider<List<Message>>((ref) {
  final messages = ref.watch(allMessagesProvider).value ?? [];
  final myId = ref
      .watch(coreNetworkClientProvider)
      .supabase
      .auth
      .currentUser
      ?.id;
  if (myId == null) return [];

  final Map<String, Message> latest = {};
  for (final msg in messages) {
    if (msg.loadId != null) {
      latest[msg.loadId!] = msg;
    } else {
      final partnerId = msg.senderId == myId ? msg.receiverId : msg.senderId;
      if (partnerId != null) {
        latest[partnerId] = msg;
      }
    }
  }

  final list = latest.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
});

final activeChatMessagesProvider = Provider<List<Message>>((ref) {
  final selected = ref.watch(selectedChatProvider);
  final allMsgs = ref.watch(allMessagesProvider).value ?? [];
  final myId = ref
      .watch(coreNetworkClientProvider)
      .supabase
      .auth
      .currentUser
      ?.id;

  if (myId == null) return [];

  return allMsgs.where((msg) {
    if (selected.$2 != null) {
      return msg.loadId == selected.$2;
    } else if (selected.$1 != null) {
      return (msg.senderId == myId && msg.receiverId == selected.$1) ||
          (msg.senderId == selected.$1 && msg.receiverId == myId);
    }
    return false;
  }).toList();
});
