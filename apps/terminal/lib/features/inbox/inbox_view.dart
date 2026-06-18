import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/core/providers/network_provider.dart';
import 'package:terminal/features/inbox/data/messaging_providers.dart';
import 'package:terminal/features/inbox/data/message_repository.dart';
import 'package:terminal/features/inbox/presentation/widgets/announcements_view.dart';
import 'package:terminal/features/settings/providers/company_provider.dart';
import 'package:terminal/core/widgets/ui_hardening.dart';

class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  int _selectedTab = 0; // 0 for Messages, 1 for Announcements

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildContactListSkeleton(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => const SkeletonListTile(),
        childCount: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
      header: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              'Inbox',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 48),
            _buildTabButton('Messages', 0),
            const SizedBox(width: 16),
            _buildTabButton('Announcements', 1),
          ],
        ),
      ),
      content: _selectedTab == 1
          ? const AnnouncementsView()
          : Row(
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
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Conversations',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorSecondary,
                            ),
                          ),
                        ),
                      ),
                      if (conversations.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Text(
                              'No active conversations',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.resources.textFillColorTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final msg = conversations[index];
                            final isSelected =
                                (msg.loadId != null &&
                                    selected.$2 == msg.loadId) ||
                                (msg.loadId == null &&
                                    (msg.senderId == selected.$1 ||
                                        msg.receiverId == selected.$1));

                            final partnerId = msg.loadId != null
                                ? null
                                : (msg.senderId == myId
                                      ? msg.receiverId
                                      : msg.senderId);

                            final profileAsync = partnerId != null
                                ? ref.watch(userProfileProvider(partnerId))
                                : null;

                            return ListTile.selectable(
                              selected: isSelected,
                              onPressed: () {
                                if (msg.loadId != null) {
                                  ref
                                      .read(selectedChatProvider.notifier)
                                      .select(loadId: msg.loadId);
                                } else {
                                  ref
                                      .read(selectedChatProvider.notifier)
                                      .select(partnerId: partnerId);
                                }
                              },
                              leading:
                                  profileAsync?.when(
                                    data: (profile) =>
                                        _buildAvatar(profile, msg.senderName),
                                    loading: () =>
                                        _buildAvatar(null, msg.senderName),
                                    error: (_, _) =>
                                        _buildAvatar(null, msg.senderName),
                                  ) ??
                                  _buildAvatar(null, msg.senderName),
                              title: Text(
                                msg.loadId != null
                                    ? 'Load #${msg.loadId!.substring(0, 8)}'
                                    : (profileAsync?.value?.fullName ??
                                          msg.senderName ??
                                          'User'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? theme.accentColor.defaultBrushFor(
                                          theme.brightness,
                                        )
                                      : theme.resources.textFillColorPrimary,
                                ),
                              ),
                              subtitle: Text(
                                msg.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.resources.textFillColorSecondary,
                                ),
                              ),
                              trailing: Text(
                                DateFormat.Hm().format(msg.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.resources.textFillColorTertiary,
                                ),
                              ),
                            );
                          }, childCount: conversations.length),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            'Contacts',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.resources.textFillColorSecondary,
                            ),
                          ),
                        ),
                      ),
                      ref
                          .watch(companyUsersProvider)
                          .when(
                            data: (users) => SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final user = users[index];
                                final isCurrentlySelected =
                                    selected.$1 == user.id;

                                return ListTile.selectable(
                                  selected: isCurrentlySelected,
                                  onPressed: () {
                                    ref
                                        .read(selectedChatProvider.notifier)
                                        .select(partnerId: user.id);
                                  },
                                  leading: _buildAvatar(user, user.fullName),
                                  title: Text(
                                    user.fullName ?? 'Unknown User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isCurrentlySelected
                                          ? theme.accentColor.defaultBrushFor(
                                              theme.brightness,
                                            )
                                          : theme
                                                .resources
                                                .textFillColorPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    user.role.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme
                                          .resources
                                          .textFillColorSecondary,
                                    ),
                                  ),
                                );
                              }, childCount: users.length),
                            ),
                            loading: () => _buildContactListSkeleton(context),
                            error: (e, _) => SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Error loading contacts: $e'),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),

                // Main Chat Area
                Expanded(
                  child: selected.$1 == null && selected.$2 == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FluentIcons.chat_multiple_24_regular,
                                size: 64,
                                color: FluentTheme.of(context)
                                    .resources
                                    .textFillColorSecondary
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Select a conversation to start chatting',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  color: FluentTheme.of(context)
                                      .resources
                                      .textFillColorSecondary,
                                ),
                              ),
                            ],
                          ),
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
                                    icon: const Icon(
                                      FluentIcons.send_24_regular,
                                    ),
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
    final profileAsync = !isMe
        ? ref.watch(userProfileProvider(msg.senderId))
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            profileAsync?.when(
                  data: (profile) =>
                      _buildAvatar(profile, msg.senderName, radius: 14),
                  loading: () => _buildAvatar(null, msg.senderName, radius: 14),
                  error: (_, _) =>
                      _buildAvatar(null, msg.senderName, radius: 14),
                ) ??
                _buildAvatar(null, msg.senderName, radius: 14),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.45,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.accentColor.defaultBrushFor(theme.brightness)
                    : theme.resources.cardBackgroundFillColorDefault,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        msg.senderName ??
                            profileAsync?.value?.fullName ??
                            'User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: theme.accentColor.lightest,
                        ),
                      ),
                    ),
                  Text(
                    msg.content,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : theme.resources.textFillColorPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      Text(
                        DateFormat.Hm().format(msg.createdAt),
                        style: TextStyle(
                          fontSize: 9,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : theme.resources.textFillColorTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    UserProfile? profile,
    String? name, {
    double radius = 16,
  }) {
    final theme = FluentTheme.of(context);
    final initials = name?.isNotEmpty == true ? name![0].toUpperCase() : '?';

    if (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(profile.avatarUrl!),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.accentColor.defaultBrushFor(theme.brightness),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final theme = FluentTheme.of(context);
    final isSelected = _selectedTab == index;

    return HoverButton(
      onPressed: () => setState(() => _selectedTab = index),
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? theme.accentColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.accentColor
                  : theme.resources.textFillColorSecondary,
            ),
          ),
        );
      },
    );
  }

  void _handleSend() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final selected = ref.read(selectedChatProvider);
    final repo = ref.read(messageRepositoryProvider);

    _messageController.clear();

    final companyId = ref.read(currentCompanyIdProvider).value;

    await repo.sendMessage(
      content: content,
      receiverId: selected.$1,
      loadId: selected.$2,
      companyId: companyId,
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
