import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';
import '../providers/load_providers.dart';

class MessagesSidebar extends ConsumerStatefulWidget {
  final String loadId;
  final String loadReference;

  const MessagesSidebar({
    super.key,
    required this.loadId,
    required this.loadReference,
  });

  @override
  ConsumerState<MessagesSidebar> createState() => _MessagesSidebarState();
}

class _MessagesSidebarState extends ConsumerState<MessagesSidebar> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _flyoutController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({
    String? content,
    MessageType type = MessageType.text,
  }) async {
    final text = content ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (content == null) _messageController.clear();

    final result = await MessagingRepository.sendMessage(
      content: text,
      loadId: widget.loadId,
      type: type,
    );

    result.fold(
      (failure) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('Error sending message'),
              content: Text(failure.message),
              severity: InfoBarSeverity.error,
              onClose: close,
            ),
          );
        }
      },
      (_) {
        // Scroll to bottom after sending
        _scrollToBottom();
      },
    );
  }

  void _showQuickActionMenu() {
    _flyoutController.showFlyout(
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.topCenter,
      ),
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.clock_24_regular),
            text: const Text('Request ETA'),
            onPressed: () {
              final payload = QuickActionPayload(
                actionType: 'request_eta',
                label: 'Dispatch is requesting your current ETA.',
              );
              _sendMessage(
                content: jsonEncode(payload.toJson()),
                type: MessageType.quickAction,
              );
            },
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.location_24_regular),
            text: const Text('Confirm Arrival'),
            onPressed: () {
              final payload = QuickActionPayload(
                actionType: 'confirm_arrival',
                label: 'Please confirm arrival at next stop.',
              );
              _sendMessage(
                content: jsonEncode(payload.toJson()),
                type: MessageType.quickAction,
              );
            },
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.document_search_24_regular),
            text: const Text('Request POD'),
            onPressed: () {
              final payload = QuickActionPayload(
                actionType: 'upload_pod',
                label: 'Please scan and upload the POD.',
              );
              _sendMessage(
                content: jsonEncode(payload.toJson()),
                type: MessageType.quickAction,
              );
            },
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: theme.menuColor,
        border: Border(
          left: BorderSide(
            color: theme.resources.surfaceStrokeColorDefault.withValues(
              alpha: 0.1,
            ),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    FluentIcons.chat_24_regular,
                    size: 18,
                    color: theme.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dispatch Chat',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                      Text(
                        'Load #${widget.loadReference}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.dismiss_20_regular, size: 16),
                  onPressed: () {
                    ref.read(selectedLoadIdProvider.notifier).select(null);
                  },
                ),
              ],
            ),
          ),
          const Divider(),

          // Messages List
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: MessagingRepository.subscribeToLoadMessages(
                widget.loadId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: ProgressRing());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.chat_off_24_regular,
                          size: 40,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Auto scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(message: message);
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.menuColor,
              border: Border(
                top: BorderSide(
                  color: theme.resources.surfaceStrokeColorDefault.withValues(
                    alpha: 0.05,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                FlyoutTarget(
                  controller: _flyoutController,
                  child: GestureDetector(
                    onTap: _showQuickActionMenu,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        FluentIcons.add_24_regular,
                        size: 16,
                        color: theme.accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    controller: _messageController,
                    placeholder: 'Type a message...',
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: FilledButton(
                    onPressed: _sendMessage,
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    child: const Icon(FluentIcons.send_24_regular, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final isMe = message.senderId == user?.id;

    if (message.type == MessageType.quickAction) {
      return _buildQuickActionPreview(context, theme, isMe);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                message.senderName ?? 'Unknown',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.resources.textFillColorSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF009688)
                  : theme.resources.surfaceStrokeColorDefault.withValues(
                      alpha: 0.05,
                    ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white
                        : theme.resources.textFillColorPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(message.createdAt),
                  style: TextStyle(
                    fontSize: 9,
                    color:
                        (isMe
                                ? Colors.white
                                : theme.resources.textFillColorSecondary)
                            .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionPreview(
    BuildContext context,
    FluentThemeData theme,
    bool isMe,
  ) {
    final payload = message.quickActionPayload;
    if (payload == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.accentColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FluentIcons.flash_24_regular,
                    size: 14,
                    color: theme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'QUICK ACTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                payload.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(message.createdAt),
                style: TextStyle(
                  fontSize: 9,
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
