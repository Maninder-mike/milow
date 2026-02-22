import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/core/providers/network_provider.dart';
import 'data/messaging_providers.dart';
import 'data/message_repository.dart';

class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Note: If messaging_providers.g.dart is missing, this will show lint errors.
    // In a real environment, run `flutter pub run build_runner build`.
    final conversations = ref.watch(conversationsProvider);
    final selected = ref.watch(selectedChatProvider);
    final activeMessages = ref.watch(activeChatMessagesProvider);
    final myId = ref
        .watch(coreNetworkClientProvider)
        .supabase
        .auth
        .currentUser
        ?.id;

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Row(
        children: [
          // Sidebar: Conversation List
          Container(
            width: 300,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: FluentTheme.of(
                    context,
                  ).resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Messages',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final msg = conversations[index];
                      final isSelected =
                          (msg.loadId != null && selected.$2 == msg.loadId) ||
                          (msg.loadId == null &&
                              (msg.senderId == selected.$1 ||
                                  msg.receiverId == selected.$1));

                      return ListTile.selectable(
                        selected: isSelected,
                        onPressed: () {
                          if (msg.loadId != null) {
                            ref
                                .read(selectedChatProvider.notifier)
                                .select(loadId: msg.loadId);
                          } else {
                            final partnerId = msg.senderId == myId
                                ? msg.receiverId
                                : msg.senderId;
                            ref
                                .read(selectedChatProvider.notifier)
                                .select(partnerId: partnerId);
                          }
                        },
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(msg.senderName?[0].toUpperCase() ?? '?'),
                        ),
                        title: Text(
                          msg.loadId != null
                              ? 'Load #${msg.loadId!.substring(0, 8)}'
                              : (msg.senderName ?? 'User'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          msg.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          DateFormat.Hm().format(msg.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: FluentTheme.of(
                              context,
                            ).resources.textFillColorSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Chat Area
          Expanded(
            child: selected.$1 == null && selected.$2 == null
                ? const Center(
                    child: Text('Select a conversation to start chatting'),
                  )
                : Column(
                    children: [
                      // Chat Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: FluentTheme.of(
                                context,
                              ).resources.dividerStrokeColorDefault,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              selected.$2 != null
                                  ? 'Load Chat'
                                  : 'Direct Message',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Message List
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(24),
                          itemCount: activeMessages.length,
                          itemBuilder: (context, index) {
                            final msg = activeMessages[index];
                            final isMe = msg.senderId == myId;
                            return _buildMessageBubble(msg, isMe);
                          },
                        ),
                      ),

                      // Message Input
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextBox(
                                controller: _messageController,
                                placeholder: 'Type a message...',
                                onSubmitted: (_) => _handleSend(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(FluentIcons.send),
                              onPressed: _handleSend,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    final theme = FluentTheme.of(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.4,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? theme.accentColor.defaultBrushFor(theme.brightness)
              : theme.resources.cardBackgroundFillColorDefault,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                msg.senderName ?? 'User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: theme.accentColor.defaultBrushFor(theme.brightness),
                ),
              ),
            Text(
              msg.content,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : theme.resources.textFillColorPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat.Hm().format(msg.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.7)
                      : theme.resources.textFillColorSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final selected = ref.read(selectedChatProvider);
    final repo = ref.read(messageRepositoryProvider);

    _messageController.clear();

    await repo.sendMessage(
      content: content,
      receiverId: selected.$1,
      loadId: selected.$2,
    );

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}
