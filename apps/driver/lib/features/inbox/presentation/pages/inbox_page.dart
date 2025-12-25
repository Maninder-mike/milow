import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:milow/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<Map<String, dynamic>>>? _messagesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _messagesFuture ??= _fetchMessages();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f0f1a),
                ]
              : [
                  const Color(0xFFF0F4FF),
                  const Color(0xFFFDF2F8),
                  const Color(0xFFF0FDF4),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.inbox ?? 'Inbox',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Messages and updates',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildGlassyIconButton(Icons.search, isDark, textColor),
                    const SizedBox(width: 8),
                    // Glassy Popup Menu for "Delete Chat"
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: textColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
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
                                      color: Colors.red[400],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete Chat',
                                      style: GoogleFonts.inter(
                                        color: Colors.red[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Glassy Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF667085),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Messages'),
                      Tab(text: 'Announcements'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMessageList(isDark, textColor),
                _buildAnnouncementList(isDark, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassyIconButton(IconData icon, bool isDark, Color textColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(icon, color: textColor),
            // TODO: Implement search functionality
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Chat',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            'Are you sure you want to delete all messages? This action cannot be undone.',
            style: GoogleFonts.inter(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: Colors.red[400],
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Message',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            'Delete this message?',
            style: GoogleFonts.inter(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: Colors.red[400],
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
          content: Text('Message deleted', style: GoogleFonts.inter()),
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
              style: GoogleFonts.inter(),
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
              style: GoogleFonts.inter(),
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

  Widget _buildMessageList(bool isDark, Color textColor) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildPlaceholderCard(
                  isDark,
                  textColor,
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
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF6C5CE7)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                senderRole?.toUpperCase() ?? 'DISPATCH',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6C5CE7),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '•',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                senderName ?? 'Support',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          content,
                          style: GoogleFonts.inter(
                            color: isMe ? Colors.white : textColor,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.jm().format(date),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
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

  Widget _buildAnnouncementList(bool isDark, Color textColor) {
    final stream = Supabase.instance.client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final announcements = snapshot.data!;

        if (announcements.isEmpty) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildPlaceholderCard(
                isDark,
                textColor,
                'Announcements will appear here',
                Icons.notifications_none,
              ),
              const SizedBox(height: 16),
              _buildInfoCard(isDark),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = announcements[index];
            final title = item['title'] ?? 'New Message';
            final body = item['body'] ?? '';
            final date =
                (DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now())
                    .toLocal();

            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: const Color(
                    0xFF6C5CE7,
                  ).withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.rocket_launch,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
                title: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat.yMMMd().format(date)} ${DateFormat.jm().format(date)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholderCard(
    bool isDark,
    Color textColor,
    String message,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.7),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: const Color(0xFF6C5CE7)),
                ),
                const SizedBox(height: 20),
                Text(
                  'No content yet',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF667085),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF6C5CE7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Announcements',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is where you\'ll receive general updates from your company and system checks.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6C5CE7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
