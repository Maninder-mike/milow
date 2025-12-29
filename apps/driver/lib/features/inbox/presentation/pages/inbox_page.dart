import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; // Still used for fallback if needed, but we prefer Theme.
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  Future<List<Map<String, dynamic>>>? _messagesFuture;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _messagesFuture ??= _fetchMessages();

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
              context.go('/dashboard');
            }
          },
        ),
        title: Text(
          'Inbox',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
                    const SizedBox(width: 8),
                    Text(
                      'Delete Chat',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildMessageList(),
    );
  }

  Future<void> _confirmDeleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
            'Are you sure you want to delete all messages? This action cannot be undone.',
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
                style: TextStyle(
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
      await _deleteChat();
    }
  }

  Future<void> _confirmDeleteSingleMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Delete this message?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: TextStyle(
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
      await _deleteSingleMessage(messageId);
    }
  }

  Future<void> _deleteSingleMessage(String messageId) async {
    // 1. Local hide (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = prefs.getStringList('deleted_message_ids') ?? [];
    if (!deletedIds.contains(messageId)) {
      deletedIds.add(messageId);
      await prefs.setStringList('deleted_message_ids', deletedIds);
    }

    // 2. Server delete (best effort, don't block UI)
    unawaited(
      Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .then((_) => debugPrint('Single message server delete success'))
          .catchError(
            (e) => debugPrint('Single message server delete failed: $e'),
          ),
    );

    // 3. Refresh UI
    if (mounted) {
      setState(() {
        _messagesFuture = _fetchMessages();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message deleted', style: GoogleFonts.outfit()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _clearChatLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inbox_cleared_at', DateTime.now().toIso8601String());
  }

  Future<void> _deleteChat() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      debugPrint('Deleting chat for user: $myId');

      // 1. Clear locally first (GUARANTEED UI UPDATE)
      await _clearChatLocally();

      // Optimistically clear the UI
      if (mounted) {
        setState(() {
          _messagesFuture = Future.value([]);
        });
      }

      // 2. Try server-side delete (Best Effort)
      // Try deleting sent messages
      try {
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('sender_id', myId);
        debugPrint('Deleted sent messages');
      } catch (e) {
        debugPrint('Failed to delete sent messages: $e');
        // Don't show error to user if local clear worked
      }

      // Try deleting received messages
      try {
        await Supabase.instance.client
            .from('messages')
            .delete()
            .eq('receiver_id', myId);
        debugPrint('Deleted received messages');
      } catch (e) {
        debugPrint('Failed to delete received messages: $e');
        // Only log, don't show error, as we handled it locally
      }

      if (mounted) {
        setState(() {
          _messagesFuture = _fetchMessages();
        }); // Refresh UI

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chat deleted successfully',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Global delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete chat: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMessages() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('messages')
          .select('*, sender:profiles!messages_sender_id_fkey(full_name, role)')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: false);

      var messages = List<Map<String, dynamic>>.from(response);

      // Filter locally based on deleted IDs (single messages)
      final prefs = await SharedPreferences.getInstance();
      final deletedIds = prefs.getStringList('deleted_message_ids') ?? [];
      if (deletedIds.isNotEmpty) {
        messages = messages
            .where((m) => !deletedIds.contains(m['id']))
            .toList();
      }

      // Filter locally based on clear timestamp (entire chat)
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

  Widget _buildMessageList() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return const Center(child: Text('Not logged in'));

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
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _messagesFuture = _fetchMessages();
              });
              await _messagesFuture;
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildPlaceholderCard(
                  'No new messages',
                  Icons.chat_bubble_outline,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _messagesFuture = _fetchMessages();
            });
            await _messagesFuture;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: messages.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = messages[index];
              final content = item['content'] ?? '';
              final date =
                  (DateTime.tryParse(item['created_at'] ?? '') ??
                          DateTime.now())
                      .toLocal();
              final senderId = item['sender_id'];
              final isMe = senderId == myId;

              // Extract sender info
              final senderData = item['sender'];
              String? senderName;
              String? senderRole;

              if (senderData != null && senderData is Map) {
                senderName = senderData['full_name'];
                senderRole = senderData['role'];
              }

              // Fallback if data missing or standard names
              if (!isMe) {
                senderName ??= 'Unknown';
                senderRole ??= 'Dispatcher'; // Default fallback
              }

              return GestureDetector(
                onLongPress: () => _confirmDeleteSingleMessage(item['id']),
                child: Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      border: Border.all(
                        color: isMe
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    senderRole?.toUpperCase() ?? 'DISPATCH',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '•',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      senderName ?? 'Support',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              content,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: isMe
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                DateFormat.jm().format(date),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderCard(String message, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF667085);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No content yet',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.outfit(fontSize: 14, color: secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
