import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/messaging_provider.dart';
import 'package:milow_core/milow_core.dart';

class ChatDetailPage extends StatefulWidget {
  final String? partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? loadId;

  const ChatDetailPage({
    required this.partnerName,
    this.partnerId,
    this.partnerAvatarUrl,
    this.loadId,
    super.key,
  }) : assert(partnerId != null || loadId != null);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final messagingProvider = context.watch<MessagingProvider>();
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (myId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    // Filter messages for this chat
    final messages = messagingProvider.inbox.where((msg) {
      if (widget.loadId != null) {
        return msg.loadId == widget.loadId;
      } else {
        return (msg.senderId == myId && msg.receiverId == widget.partnerId) ||
            (msg.senderId == widget.partnerId && msg.receiverId == myId);
      }
    }).toList();

    // Sort by date ascending for the list view
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: widget.partnerAvatarUrl != null
                  ? NetworkImage(widget.partnerAvatarUrl!)
                  : null,
              child: widget.partnerAvatarUrl == null
                  ? Text(
                      widget.partnerName.isNotEmpty
                          ? widget.partnerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.loadId != null ? 'Load Chat' : 'Direct Message',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg.senderId == myId;
                return _buildMessageItem(msg, isMe, tokens, messagingProvider);
              },
            ),
          ),
          _buildMessageInput(messagingProvider),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    Message msg,
    bool isMe,
    DesignTokens tokens,
    MessagingProvider provider,
  ) {
    if (msg.type == MessageType.quickAction) {
      final payload = msg.quickActionPayload;
      if (payload != null) {
        return _buildQuickActionCard(payload, msg, isMe, tokens, provider);
      }
    }
    return _buildMessageBubble(msg, isMe, tokens);
  }

  Widget _buildQuickActionCard(
    QuickActionPayload payload,
    Message msg,
    bool isMe,
    DesignTokens tokens,
    MessagingProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isCompleted = payload.status == 'completed';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? tokens.success.withValues(alpha: 0.5)
                : colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.bolt_rounded,
                  color: isCompleted ? tokens.success : colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMe ? 'Sent Quick Action' : 'Action Required',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? tokens.success : colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              payload.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (!isMe && !isCompleted)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _handleQuickAction(payload, msg, provider),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_getActionLabel(payload.actionType)),
                ),
              )
            else if (isCompleted)
              Row(
                children: [
                  Icon(Icons.done, size: 14, color: tokens.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Completed',
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat.jm().format(msg.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'request_eta':
        return 'Send Current ETA';
      case 'confirm_arrival':
        return 'Confirm Arrival';
      case 'upload_pod':
        return 'Scan POD';
      default:
        return 'Confirm';
    }
  }

  void _handleQuickAction(
    QuickActionPayload payload,
    Message msg,
    MessagingProvider provider,
  ) async {
    // 1. Execute logic based on type
    String responseContent = 'Confirmed: ${payload.label}';

    if (payload.actionType == 'upload_pod') {
      final result = await context.push(
        '/scan-document',
        extra: {'tripId': msg.loadId, 'initialDocumentType': 'pod'},
      );
      if (result == null) return; // Cancelled
      responseContent = 'POD Uploaded';
    } else if (payload.actionType == 'request_eta') {
      // In a real app, calculate ETA or show picker
      responseContent = 'ETA to next stop: 45 mins';
    }

    // 2. Mark action as completed locally/remotely
    // In this MVP, we just send a reply. In a full implementation,
    // we would update the original message status in DB.

    // 3. Send reply
    await provider.sendMessage(
      content: responseContent,
      loadId: msg.loadId,
      receiverId: msg.senderId,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Action completed!')));
  }

  Widget _buildMessageBubble(Message msg, bool isMe, DesignTokens tokens) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.Hm().format(msg.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(MessagingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _handleSend(provider),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend(MessagingProvider provider) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    await provider.sendMessage(
      content: content,
      loadId: widget.loadId,
      receiverId: widget.partnerId,
    );

    // Scroll to bottom
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    }
  }
}
