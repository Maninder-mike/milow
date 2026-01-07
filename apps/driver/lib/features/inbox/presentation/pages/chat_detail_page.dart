import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/constants/design_tokens.dart';

/// Chat detail page showing full conversation with a specific person
class ChatDetailPage extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatarUrl;

  const ChatDetailPage({
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatarUrl,
    super.key,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  Future<List<Map<String, dynamic>>>? _messagesFuture;
  StreamSubscription? _realtimeSubscription;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _fetchMessages();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToRealtime() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    _realtimeSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((data) {
          // Refresh when new messages arrive
          if (mounted) {
            setState(() {
              _messagesFuture = _fetchMessages();
            });
          }
        });
  }

  Future<List<Map<String, dynamic>>> _fetchMessages() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      // Fetch messages between me and the partner
      final List<dynamic> response = await Supabase.instance.client
          .from('messages')
          .select(
            '*, sender:profiles!messages_sender_id_fkey(full_name, role, avatar_url)',
          )
          .or(
            'and(sender_id.eq.$myId,receiver_id.eq.${widget.partnerId}),and(sender_id.eq.${widget.partnerId},receiver_id.eq.$myId)',
          )
          .order('created_at', ascending: true);

      var messages = List<Map<String, dynamic>>.from(response);

      // Filter based on local prefs
      final prefs = await SharedPreferences.getInstance();

      // Filter deleted message IDs
      final deletedIds = prefs.getStringList('deleted_message_ids') ?? [];
      if (deletedIds.isNotEmpty) {
        messages = messages
            .where((m) => !deletedIds.contains(m['id']))
            .toList();
      }

      // Filter based on clear timestamp
      final clearedAtStr = prefs.getString('inbox_cleared_at');
      if (clearedAtStr != null) {
        final clearedAt = DateTime.parse(clearedAtStr);
        messages = messages.where((m) {
          final createdAt = DateTime.tryParse(m['created_at'] ?? '');
          if (createdAt == null) return true;
          return createdAt.isAfter(clearedAt);
        }).toList();
      }

      return messages;
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final initials = widget.partnerName
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/inbox');
            }
          },
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
                      initials,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: tokens.spacingM),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.partnerName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Dispatcher',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteChat();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete Chat',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          // Message input (placeholder for now)
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _messagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: context.tokens.spacingM),
                Text(
                  'No messages yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(context.tokens.spacingM),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg['sender_id'] == myId;
            return _buildMessageBubble(msg, isMe);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final tokens = context.tokens;
    final content = msg['content'] ?? '';
    final date = (DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now())
        .toLocal();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: tokens.spacingS,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(tokens.shapeL),
            topRight: Radius.circular(tokens.shapeL),
            bottomLeft: Radius.circular(isMe ? tokens.shapeL : tokens.shapeXS),
            bottomRight: Radius.circular(isMe ? tokens.shapeXS : tokens.shapeL),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacingM,
            vertical: tokens.spacingS + 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isMe
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: tokens.spacingXS),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.Hm().format(date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isMe) ...[
                    SizedBox(width: tokens.spacingXS),
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
      ),
    );
  }

  Widget _buildMessageInput() {
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachments coming soon')),
                );
              },
              icon: Icon(
                Icons.attach_file_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            // Message input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(tokens.shapeL),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: tokens.spacingM,
                      vertical: tokens.spacingS + 4,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            SizedBox(width: tokens.spacingS),
            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: IconButton.filled(
                onPressed: _messageController.text.trim().isEmpty || _isSending
                    ? null
                    : _sendMessage,
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  disabledBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': myId,
        'receiver_id': widget.partnerId,
        'content': content,
      });

      _messageController.clear();

      // Refresh messages
      setState(() {
        _messagesFuture = _fetchMessages();
      });

      // Scroll to bottom after messages load
      await _messagesFuture;
      if (mounted && _scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _confirmDeleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
            'Are you sure you want to delete this conversation?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Mark chat as cleared from this timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'inbox_cleared_at',
        DateTime.now().toIso8601String(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat deleted'),
            backgroundColor: context.tokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    }
  }
}
