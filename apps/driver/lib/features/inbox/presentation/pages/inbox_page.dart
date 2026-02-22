import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/profile_provider.dart';
import 'package:milow/core/services/messaging_provider.dart';
import 'package:milow_core/milow_core.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final messagingProvider = context.watch<MessagingProvider>();
    final profileProvider = context.watch<ProfileProvider>();

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
          profileProvider.companyName ?? 'Inbox',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _showNewMessageDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Conversations'),
            Tab(text: 'Loads'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(tokens.spacingM),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search messages...',
              onChanged: (value) => setState(() => _searchQuery = value),
              leading: const Icon(Icons.search),
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          // Conversation List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConversationList(
                  messagingProvider: messagingProvider,
                  isLoadChat: false,
                ),
                _buildConversationList(
                  messagingProvider: messagingProvider,
                  isLoadChat: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList({
    required MessagingProvider messagingProvider,
    required bool isLoadChat,
  }) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return const Center(child: Text('Please log in'));

    final messages = messagingProvider.inbox;

    // 1. Group by partner/load
    final Map<String, Message> latestMessages = {};
    for (final msg in messages) {
      if (isLoadChat) {
        if (msg.loadId != null && !latestMessages.containsKey(msg.loadId!)) {
          latestMessages[msg.loadId!] = msg;
        }
      } else {
        if (msg.loadId == null) {
          final partnerId = msg.senderId == myId
              ? msg.receiverId
              : msg.senderId;
          if (partnerId != null && !latestMessages.containsKey(partnerId)) {
            latestMessages[partnerId] = msg;
          }
        }
      }
    }

    var conversations = latestMessages.values.toList();

    // 2. Filter by search
    if (_searchQuery.isNotEmpty) {
      conversations = conversations.where((msg) {
        final searchLower = _searchQuery.toLowerCase();
        return (msg.senderName?.toLowerCase().contains(searchLower) ?? false) ||
            msg.content.toLowerCase().contains(searchLower);
      }).toList();
    }

    if (conversations.isEmpty) {
      return _buildEmptyState(isLoadChat);
    }

    return ListView.builder(
      itemCount: conversations.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final msg = conversations[index];
        return _buildConversationTile(msg, myId, isLoadChat: isLoadChat);
      },
    );
  }

  Widget _buildConversationTile(
    Message msg,
    String myId, {
    required bool isLoadChat,
  }) {
    final isMe = msg.senderId == myId;
    final partnerId = isMe ? msg.receiverId : msg.senderId;

    String title = isLoadChat ? 'Load Chat' : (msg.senderName ?? 'Dispatcher');
    if (isMe && !isLoadChat) {
      title = 'Dispatcher'; // Assuming we're messaging dispatch
    }

    return ListTile(
      onTap: () {
        context.push(
          '/chat',
          extra: {
            'partnerId': isLoadChat ? null : partnerId,
            'partnerName': title,
            'partnerAvatarUrl': msg.senderAvatarUrl,
            'loadId': isLoadChat ? msg.loadId : null,
          },
        );
      },
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: msg.senderAvatarUrl != null
            ? NetworkImage(msg.senderAvatarUrl!)
            : null,
        child: msg.senderAvatarUrl == null
            ? Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatMessageTime(msg.createdAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          if (isMe) ...[
            Icon(
              Icons.done_all,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              msg.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(date);
    } else if (now.difference(date).inDays < 7) {
      return DateFormat.E().format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Widget _buildEmptyState(bool isLoadChat) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLoadChat
                ? Icons.local_shipping_outlined
                : Icons.chat_bubble_outline_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isLoadChat ? 'No load chats yet' : 'No messages yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isLoadChat
                ? 'Messages for your active load will appear here'
                : 'Start a conversation with your dispatcher',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showNewMessageDialog() {
    // Re-use the existing logic but simplified
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NewMessageBottomSheet(),
    );
  }
}

class _NewMessageBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.all(tokens.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.shapeL),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'New Message',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchContacts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contacts = snapshot.data!;
                if (contacts.isEmpty) {
                  return const Center(child: Text('No contacts found'));
                }
                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        context.push(
                          '/chat',
                          extra: {
                            'partnerId': contact['id'],
                            'partnerName': contact['full_name'],
                            'partnerAvatarUrl': contact['avatar_url'],
                          },
                        );
                      },
                      leading: CircleAvatar(
                        backgroundImage: contact['avatar_url'] != null
                            ? NetworkImage(contact['avatar_url'])
                            : null,
                        child: contact['avatar_url'] == null
                            ? Text((contact['full_name'] as String)[0])
                            : null,
                      ),
                      title: Text(contact['full_name']),
                      subtitle: Text(contact['role'] ?? 'Staff'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchContacts() async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return [];

    final profile = await supabase
        .from('profiles')
        .select('company_id')
        .eq('id', myId)
        .single();

    final companyId = profile['company_id'] as String?;
    if (companyId == null) return [];

    final response = await supabase
        .from('profiles')
        .select('id, full_name, role, avatar_url')
        .eq('company_id', companyId)
        .neq('role', 'driver') // Only admins/dispatchers
        .order('full_name');

    return List<Map<String, dynamic>>.from(response);
  }
}
