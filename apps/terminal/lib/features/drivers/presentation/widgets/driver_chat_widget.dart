import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DriverChatWidget extends ConsumerStatefulWidget {
  final String driverId;
  final String driverName;

  const DriverChatWidget({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  ConsumerState<DriverChatWidget> createState() => _DriverChatWidgetState();
}

class _DriverChatWidgetState extends ConsumerState<DriverChatWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  late Stream<List<Map<String, dynamic>>> _messagesStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _setupStream();
  }

  void _setupStream() {
    if (_currentUserId == null) return;

    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          // Filter locally for this conversation if RLS doesn't do it strictly enough
          // or just to be safe. Ideally RLS handles filtering, but stream might return all users if admin.
          return data.where((msg) {
            final senderId = msg['sender_id'];
            final receiverId = msg['receiver_id'];
            return (senderId == _currentUserId &&
                    receiverId == widget.driverId) ||
                (senderId == widget.driverId && receiverId == _currentUserId);
          }).toList();
        });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUserId == null) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('messages').insert({
        'content': content,
        'receiver_id': widget.driverId,
        'sender_id': _currentUserId,
        // 'is_read': false, // Let DB default handle this
      });
      _messageController.clear();
      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('Error Sending Message'),
              content: Text(e.toString()),
              severity: InfoBarSeverity.error,
              onClose: close,
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Please log in to chat'));
    }

    final theme = FluentTheme.of(context);

    return Container(
      height: 500, // Fixed height for the chat area
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.chat_solid, color: theme.accentColor),
                const SizedBox(width: 8),
                Text(
                  'Chat with ${widget.driverName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: ProgressRing());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  );
                }

                // Scroll to bottom on initial load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients &&
                      _scrollController.offset == 0) {
                    // Only auto-scroll if we are roughly at the top (start)?
                    // Actually better to scroll to bottom once data loaded.
                    // For now, let's just let user scroll or basic reverse list view might be better
                    // But we ordered ascending, so standard listview + controller jump.
                    // To keep it simple, we stick to ascending order and scroll to end.
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _currentUserId;
                    final content = msg['content'] as String? ?? '';
                    final createdAt = DateTime.parse(msg['created_at']);

                    return _buildMessageBubble(
                      context,
                      content,
                      createdAt,
                      isMe,
                      theme,
                    );
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _messageController,
                    placeholder: 'Type a message...',
                    maxLines: null,
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(borderRadius: BorderRadius.circular(20)),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    child: _isSending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: ProgressRing(
                              strokeWidth: 2,
                              activeColor: Colors.white,
                            ),
                          )
                        : const Icon(FluentIcons.send, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    String content,
    DateTime timestamp,
    bool isMe,
    FluentThemeData theme,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? theme.accentColor
              : theme.resources.controlFillColorSecondary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe
                ? const Radius.circular(12)
                : const Radius.circular(0),
            bottomRight: isMe
                ? const Radius.circular(0)
                : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isMe ? Colors.white : theme.typography.body?.color,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(timestamp),
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : theme.resources.textFillColorSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
