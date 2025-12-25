import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:milow/core/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selectedFilter = 'All';
  List<NotificationItem> _notifications = [];
  final Set<String> _locallyDeletedIds = {};

  // Used for filtering locally after fetching
  List<NotificationItem> get _filteredNotifications {
    if (_selectedFilter == 'All') {
      return _notifications;
    } else if (_selectedFilter == 'Reminders') {
      return _notifications
          .where((n) => n.type == NotificationType.reminder)
          .toList();
    } else if (_selectedFilter == 'Company') {
      return _notifications
          .where((n) => n.type == NotificationType.company)
          .toList();
    } else if (_selectedFilter == 'Messages') {
      return _notifications
          .where((n) => n.type == NotificationType.message)
          .toList();
    } else {
      return _notifications
          .where((n) => n.type == NotificationType.news)
          .toList();
    }
  }

  Future<void> _markAsRead(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
    // Optimistic update handled by StreamBuilder usually, but local state might lag slightly
    // NotificationService count update:
    await NotificationService.instance.refreshUnreadCount();
  }

  Future<void> _markAllAsRead() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);

    await NotificationService.instance.refreshUnreadCount();
  }

  // Clean up notification delete if needed
  Future<void> _deleteNotification(String id) async {
    await Supabase.instance.client.from('notifications').delete().eq('id', id);
    await NotificationService.instance.refreshUnreadCount();
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.reminder:
        return Icons.notification_important;
      case NotificationType.company:
        return Icons.business;
      case NotificationType.news:
        return Icons.newspaper;
      case NotificationType.message:
        return Icons.chat_bubble_outline;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.reminder:
        return const Color(0xFFF59E0B); // Amber/Orange for reminders
      case NotificationType.company:
        return const Color(0xFF007AFF); // Blue for company
      case NotificationType.news:
        return const Color(0xFF10B981); // Green for news
      case NotificationType.message:
        return const Color(0xFF8B5CF6); // Violet for messages
    }
  }

  String _getNotificationLabel(NotificationType type) {
    switch (type) {
      case NotificationType.reminder:
        return 'Reminder';
      case NotificationType.company:
        return 'Company';
      case NotificationType.news:
        return 'News';
      case NotificationType.message:
        return 'Message';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('notifications')
              .stream(primaryKey: ['id'])
              .eq('user_id', Supabase.instance.client.auth.currentUser!.id),
          builder: (context, snapshot) {
            int unread = 0;
            if (snapshot.hasData) {
              unread = snapshot.data!
                  .where((e) => e['is_read'] == false)
                  .length;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                if (unread > 0)
                  Text(
                    '$unread unread',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF98A2B3),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!
              .where((e) => !_locallyDeletedIds.contains(e['id']))
              .map((e) => NotificationItem.fromJson(e))
              .toList();

          // Update local state for filtering
          // Note: Avoid setting state in build, but for this simple filter logic it's okay to just reuse variable
          // or we can use a separate variable in build.
          // Better: just use `notifications` local var and filter it.
          // But `_filteredNotifications` depends on `_notifications`.
          // I'll assign it here but wrapped in a check to avoid rebuild loops if I was calling setState (I am not).
          _notifications = notifications;

          return Column(
            children: [
              // Filter Chips
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', notifications.length),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Reminders',
                        notifications
                            .where((n) => n.type == NotificationType.reminder)
                            .length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Company',
                        notifications
                            .where((n) => n.type == NotificationType.company)
                            .length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'News',
                        notifications
                            .where((n) => n.type == NotificationType.news)
                            .length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Messages',
                        notifications
                            .where((n) => n.type == NotificationType.message)
                            .length,
                      ),
                    ],
                  ),
                ),
              ),
              // Notifications List
              Expanded(
                child: _filteredNotifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = _filteredNotifications[index];
                          return Dismissible(
                            key: Key(notification.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              color: const Color(0xFFEF4444),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Notification?'),
                                  content: const Text(
                                    'Are you sure you want to delete this notification?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldDelete == true) {
                                await _deleteNotification(notification.id);
                                return true;
                              }
                              return false;
                            },
                            onDismissed: (_) {
                              setState(() {
                                _locallyDeletedIds.add(notification.id);
                              });
                            },
                            child: _buildNotificationCard(notification),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007AFF)
              : isDark
              ? const Color(0xFF2A2A2A)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF007AFF)
                : isDark
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF007AFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return GestureDetector(
      onTap: () => _markAsRead(notification.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !notification.isRead
                ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                : Colors.transparent,
            width: !notification.isRead ? 1.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(
                      notification.type,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF007AFF),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF667085),
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF98A2B3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF98A2B3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(
                                notification.type,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getNotificationLabel(notification.type),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getNotificationColor(notification.type),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (notification.type == NotificationType.company &&
                !notification.isRead) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _rejectInvite(notification.id),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final adminId =
                            notification.data?['admin_id'] as String?;
                        if (adminId != null) {
                          _approveInvite(notification.id, adminId);
                        }
                      },
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveInvite(String notificationId, String adminId) async {
    try {
      await _markAsRead(notificationId);

      // Notify the admin that driver accepted
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final userProfile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .single();

      final driverName = userProfile['full_name'] ?? 'A driver';

      await Supabase.instance.client.from('notifications').insert({
        'user_id': adminId,
        'type': 'company_invite',
        'title': 'Verification Accepted',
        'body':
            '$driverName has accepted your verification request and granted data access.',
        'data': {'driver_id': userId, 'driver_name': driverName},
        'is_read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation accepted. Data sharing enabled.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectInvite(String notificationId) async {
    try {
      // Get admin info from notification data before marking as read
      final notification = _filteredNotifications.firstWhere(
        (n) => n.id == notificationId,
      );
      final adminId = notification.data?['admin_id'] as String?;

      await Supabase.instance.client.rpc('reject_company_invite');
      await _markAsRead(notificationId);

      // Notify the admin that driver declined
      if (adminId != null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        final userProfile = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .single();

        final driverName = userProfile['full_name'] ?? 'A driver';

        await Supabase.instance.client.from('notifications').insert({
          'user_id': adminId,
          'type': 'company_invite',
          'title': 'Verification Declined',
          'body':
              '$driverName has declined your verification request. Data access has been revoked.',
          'data': {'driver_id': userId, 'driver_name': driverName},
          'is_read': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined. Admin access revoked.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error declining invite: $e')));
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Color(0xFF007AFF),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }
}

class NotificationItem {
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString().split('.').last,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  static NotificationItem fromJson(Map<String, dynamic> json) {
    NotificationType type;
    final typeStr = json['type'] as String?;
    if (typeStr == 'reminder') {
      type = NotificationType.reminder;
    } else if (typeStr == 'company' || typeStr == 'company_invite') {
      type = NotificationType.company;
    } else if (typeStr == 'message') {
      type = NotificationType.message;
    } else {
      type = NotificationType.news;
    }

    return NotificationItem(
      id: json['id'],
      type: type,
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? json['body'] ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] ?? json['created_at'] ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      data: json['data'],
    );
  }

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.data,
  });
}
