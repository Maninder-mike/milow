import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/profile_provider.dart';
import 'package:milow/features/inbox/presentation/pages/chat_detail_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  Future<List<Map<String, dynamic>>>? _conversationsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _fetchConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

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
          context.watch<ProfileProvider>().companyName ?? 'Inbox',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              _buildMenuItem(
                context,
                'new_message',
                Icons.add_comment_outlined,
                'New Message',
              ),
              _buildMenuItem(
                context,
                'starred',
                Icons.star_outline_rounded,
                'Starred Messages',
              ),
              _buildMenuItem(context, 'groups', Icons.group_outlined, 'Groups'),
              const PopupMenuDivider(),
              _buildMenuItem(
                context,
                'settings',
                Icons.settings_outlined,
                'Settings',
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete All Chats',
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
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacingM,
              vertical: tokens.spacingS,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(tokens.shapeFull),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: tokens.spacingM,
                    vertical: tokens.spacingM,
                  ),
                ),
              ),
            ),
          ),
          // Conversation List
          Expanded(child: _buildConversationList()),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'new_message':
        _showNewMessageDialog();
        break;
      case 'starred':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starred messages coming soon')),
        );
        break;
      case 'groups':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Groups coming soon')));
        break;
      case 'settings':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
        break;
      case 'delete_all':
        _confirmDeleteAllChats();
        break;
    }
  }

  Future<void> _confirmDeleteAllChats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete All Chats'),
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
      await _deleteAllChats();
    }
  }

  Future<void> _deleteAllChats() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Clear locally first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'inbox_cleared_at',
        DateTime.now().toIso8601String(),
      );

      // Optimistically clear UI
      if (mounted) {
        setState(() {
          _conversationsFuture = Future.value([]);
        });
      }

      // Server-side delete (best effort)
      unawaited(
        Supabase.instance.client
            .from('messages')
            .delete()
            .eq('sender_id', myId)
            .then((_) => debugPrint('Sent messages deleted'))
            .catchError((e) => debugPrint('Failed to delete sent: $e')),
      );

      unawaited(
        Supabase.instance.client
            .from('messages')
            .delete()
            .eq('receiver_id', myId)
            .then((_) => debugPrint('Received messages deleted'))
            .catchError((e) => debugPrint('Failed to delete received: $e')),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All chats deleted'),
            backgroundColor: context.tokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchConversations() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('messages')
          .select(
            '*, sender:profiles!messages_sender_id_fkey(full_name, role, avatar_url)',
          )
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: false);

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

      // Group by conversation partner (sender_id for received, receiver_id for sent)
      final Map<String, Map<String, dynamic>> conversations = {};

      for (final msg in messages) {
        final senderId = msg['sender_id'];
        final isMe = senderId == myId;

        // The conversation partner is the other person
        final partnerId = isMe ? msg['receiver_id'] : senderId;

        // Only show conversations from dispatchers (not self-to-self)
        if (partnerId == myId) continue;

        // Keep only the latest message per conversation
        if (!conversations.containsKey(partnerId)) {
          conversations[partnerId] = msg;
        }
      }

      return conversations.values.toList();
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return [];
    }
  }

  Widget _buildConversationList() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _conversationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var conversations = snapshot.data ?? [];

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          conversations = conversations.where((conv) {
            final senderData = conv['sender'] as Map<String, dynamic>?;
            final name = (senderData?['full_name'] ?? 'Admin')
                .toString()
                .toLowerCase();
            final content = (conv['content'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) ||
                content.contains(_searchQuery);
          }).toList();
        }

        if (conversations.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                _buildEmptyState(),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _buildConversationTile(conv, myId);
            },
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _conversationsFuture = _fetchConversations();
    });
    await _conversationsFuture;
  }

  Widget _buildConversationTile(Map<String, dynamic> conv, String myId) {
    final tokens = context.tokens;
    final senderId = conv['sender_id'];
    final isMe = senderId == myId;

    // Get sender info
    final senderData = conv['sender'];
    String name = 'Admin';
    String? avatarUrl;

    if (senderData != null && senderData is Map) {
      name = senderData['full_name'] ?? 'Admin';
      avatarUrl = senderData['avatar_url'];
    }

    // For messages I sent, show "You" or receiver info
    if (isMe) {
      name = 'You';
    }

    final content = conv['content'] ?? '';
    final date = (DateTime.tryParse(conv['created_at'] ?? '') ?? DateTime.now())
        .toLocal();
    final formattedTime = _formatMessageTime(date);

    // Generate initials for avatar
    final initials = name
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    // Get the partner ID for navigation
    final partnerId = isMe ? conv['receiver_id'] : senderId;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              partnerId: partnerId ?? '',
              partnerName: isMe ? 'Dispatcher' : name,
              partnerAvatarUrl: avatarUrl,
            ),
          ),
        );
      },
      onLongPress: () => _showConversationOptions(conv),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingM,
          vertical: tokens.spacingS + 4,
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      initials,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: tokens.spacingM),
            // Name and Message Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacingXS),
                  Row(
                    children: [
                      if (isMe) ...[
                        Icon(
                          Icons.done_all,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: tokens.spacingXS),
                      ],
                      Expanded(
                        child: Text(
                          content,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(date); // "14:30"
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat.E().format(date); // "Mon", "Tue"
    } else {
      return DateFormat('yyyy-MM-dd').format(date); // "2026-01-05"
    }
  }

  void _showConversationOptions(Map<String, dynamic> conv) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(context.tokens.spacingM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Star conversation'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Starred (coming soon)')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('Mute notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Muted (coming soon)')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Delete conversation',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteConversation(conv['id']);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteConversation(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Conversation'),
          content: const Text('Delete this conversation?'),
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
      // Hide locally
      final prefs = await SharedPreferences.getInstance();
      final deletedIds = prefs.getStringList('deleted_message_ids') ?? [];
      if (!deletedIds.contains(messageId)) {
        deletedIds.add(messageId);
        await prefs.setStringList('deleted_message_ids', deletedIds);
      }

      // Refresh UI
      if (mounted) {
        setState(() {
          _conversationsFuture = _fetchConversations();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation deleted'),
            backgroundColor: context.tokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    final tokens = context.tokens;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(tokens.spacingXL),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: tokens.spacingL),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          SizedBox(height: tokens.spacingS),
          Text(
            'Messages from your dispatcher will appear here',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Fetch all company contacts (dispatcher, admin, safety, etc.)
  Future<List<Map<String, dynamic>>> _fetchCompanyContacts() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      // First get the driver's company_id
      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('company_id, company_name')
          .eq('id', myId)
          .maybeSingle();

      debugPrint('My profile: $myProfile');

      final companyId = myProfile?['company_id'] as String?;
      if (companyId == null || companyId.isEmpty) {
        debugPrint('Driver has no company_id');
        return [];
      }

      debugPrint('Fetching contacts for company_id: $companyId');

      // Fetch all users from the same company
      final List<dynamic> response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, role, avatar_url, company_id')
          .eq('company_id', companyId)
          .neq('id', myId);

      debugPrint(
        'Found ${response.length} profiles with company_id: $companyId',
      );

      // Filter out drivers client-side
      final contacts = List<Map<String, dynamic>>.from(
        response,
      ).where((p) => p['role']?.toString().toLowerCase() != 'driver').toList();

      debugPrint('Filtered to ${contacts.length} non-driver contacts');
      for (var c in contacts) {
        debugPrint('Contact: ${c['full_name']} (${c['role']})');
      }

      return contacts;
    } catch (e) {
      debugPrint('Error fetching company contacts: $e');
      return [];
    }
  }

  void _showNewMessageDialog() {
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.shapeXL),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: EdgeInsets.only(top: tokens.spacingM),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.all(tokens.spacingM),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(tokens.spacingS + 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(tokens.shapeM),
                      ),
                      child: Icon(
                        Icons.add_comment_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: tokens.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Message',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Select a contact to message',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              // Contact list
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchCompanyContacts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(tokens.spacingXL),
                          child: const CircularProgressIndicator(),
                        ),
                      );
                    }

                    final contacts = snapshot.data ?? [];

                    if (contacts.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.all(tokens.spacingXL),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(tokens.spacingL),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.business_outlined,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: tokens.spacingL),
                            Text(
                              'No Company Contacts',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: tokens.spacingS),
                            Text(
                              'Accept a company invite to see dispatchers and admins here',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: tokens.spacingM),
                      shrinkWrap: true,
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 72,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return _buildContactTile(contact, ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactTile(
    Map<String, dynamic> contact,
    BuildContext sheetContext,
  ) {
    final tokens = context.tokens;
    final name = contact['full_name'] ?? 'Unknown';
    final role = contact['role'] ?? 'Staff';
    final avatarUrl = contact['avatar_url'] as String?;
    final nameStr = name.toString();
    final initials = nameStr
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    // Role display with icon and color
    IconData roleIcon;
    Color roleColor;
    switch (role.toString().toLowerCase()) {
      case 'dispatcher':
        roleIcon = Icons.headset_mic_rounded;
        roleColor = Colors.blue;
        break;
      case 'admin':
        roleIcon = Icons.admin_panel_settings_rounded;
        roleColor = Colors.deepPurple;
        break;
      case 'safety':
        roleIcon = Icons.health_and_safety_rounded;
        roleColor = Colors.green;
        break;
      case 'owner':
        roleIcon = Icons.business_rounded;
        roleColor = Colors.amber.shade700;
        break;
      default:
        roleIcon = Icons.person_rounded;
        roleColor = Theme.of(context).colorScheme.primary;
    }

    return InkWell(
      onTap: () {
        Navigator.pop(sheetContext); // Close dialog
        // Navigate to chat detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              partnerId: contact['id'],
              partnerName: name,
              partnerAvatarUrl: avatarUrl,
            ),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingM,
          vertical: tokens.spacingS + 4,
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      initials,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: tokens.spacingM),
            // Name and role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: tokens.spacingXS),
                  Row(
                    children: [
                      Icon(roleIcon, size: 14, color: roleColor),
                      SizedBox(width: tokens.spacingXS),
                      Text(
                        role.toString().toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chat icon
            Container(
              padding: EdgeInsets.all(tokens.spacingS),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(tokens.shapeM),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
