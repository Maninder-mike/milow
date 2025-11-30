import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<void> _deleteNotification(String id) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
    await _saveNotifications();
  }

  String _selectedFilter = 'All';

  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString('notifications');
    if (notificationsJson != null) {
      final List<dynamic> decoded = jsonDecode(notificationsJson);
      setState(() {
        _notifications = decoded
            .map((e) => NotificationItem.fromJson(e))
            .toList();
      });
    } else {
      // If no notifications stored, use initial mock data
      setState(() {
        _notifications = [
          NotificationItem(
            id: '1',
            type: NotificationType.company,
            title: 'New Company Policy Update',
            message:
                'Please review the updated safety guidelines for long-haul trips effective next month.',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            isRead: false,
          ),
          NotificationItem(
            id: '2',
            type: NotificationType.news,
            title: 'Fuel Prices Expected to Drop',
            message:
                'Industry analysts predict a 5% decrease in diesel prices across major routes this quarter.',
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
            isRead: false,
          ),
          NotificationItem(
            id: '3',
            type: NotificationType.company,
            title: 'Maintenance Schedule Reminder',
            message:
                'Your truck #TRK-4521 is due for scheduled maintenance on Dec 15, 2025.',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            isRead: true,
          ),
          NotificationItem(
            id: '4',
            type: NotificationType.news,
            title: 'New Rest Stop Opened on I-95',
            message:
                'A new truck-friendly rest area with amenities is now open at mile marker 245.',
            timestamp: DateTime.now().subtract(const Duration(days: 2)),
            isRead: true,
          ),
          NotificationItem(
            id: '5',
            type: NotificationType.company,
            title: 'Bonus Payout Announcement',
            message:
                'Q4 performance bonuses will be processed on December 20th. Great work team!',
            timestamp: DateTime.now().subtract(const Duration(days: 3)),
            isRead: true,
          ),
          NotificationItem(
            id: '6',
            type: NotificationType.news,
            title: 'Winter Weather Advisory',
            message:
                'Heavy snowfall expected in northern routes. Check weather conditions before departure.',
            timestamp: DateTime.now().subtract(const Duration(days: 4)),
            isRead: true,
          ),
          // Additional dummy notifications
          NotificationItem(
            id: '7',
            type: NotificationType.company,
            title: 'Driver Appreciation Week',
            message:
                'Join us for special events and giveaways to celebrate our drivers!',
            timestamp: DateTime.now().subtract(const Duration(days: 5)),
            isRead: false,
          ),
          NotificationItem(
            id: '8',
            type: NotificationType.news,
            title: 'New Route Added: West Coast Express',
            message:
                'A new express route is now available for west coast deliveries.',
            timestamp: DateTime.now().subtract(const Duration(days: 6)),
            isRead: false,
          ),
          NotificationItem(
            id: '9',
            type: NotificationType.company,
            title: 'Health Insurance Update',
            message:
                'Review the new health insurance options available for all employees.',
            timestamp: DateTime.now().subtract(const Duration(days: 7)),
            isRead: true,
          ),
          NotificationItem(
            id: '10',
            type: NotificationType.news,
            title: 'Tech Upgrade: New Fleet Management App',
            message:
                'Download the new app for improved fleet tracking and communication.',
            timestamp: DateTime.now().subtract(const Duration(days: 8)),
            isRead: true,
          ),
        ];
      });
      await _saveNotifications();
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _notifications.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('notifications', encoded);
  }

  List<NotificationItem> get _filteredNotifications {
    if (_selectedFilter == 'All') {
      return _notifications;
    } else if (_selectedFilter == 'Company') {
      return _notifications
          .where((n) => n.type == NotificationType.company)
          .toList();
    } else {
      return _notifications
          .where((n) => n.type == NotificationType.news)
          .toList();
    }
  }

  void _markAsRead(String id) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == id);
      notification.isRead = true;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);

    final unreadCount = _notifications.where((n) => !n.isRead).length;

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
        title: Column(
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
            if (unreadCount > 0)
              Text(
                '$unreadCount unread',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF98A2B3),
                ),
              ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
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
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', _notifications.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Company',
                    _notifications
                        .where((n) => n.type == NotificationType.company)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'News',
                    _notifications
                        .where((n) => n.type == NotificationType.news)
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
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: const Color(0xFFEF4444),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        onDismissed: (_) =>
                            _deleteNotification(notification.id),
                        child: _buildNotificationCard(notification),
                      );
                    },
                  ),
          ),
        ],
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
      onTap: () {
        _markAsRead(notification.id);
      },
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: notification.type == NotificationType.company
                    ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                    : const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                notification.type == NotificationType.company
                    ? Icons.business
                    : Icons.newspaper,
                color: notification.type == NotificationType.company
                    ? const Color(0xFF007AFF)
                    : const Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Content
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
                            color: Theme.of(context).textTheme.bodyLarge?.color,
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
                      // Removed delete icon button for swipe-to-delete only
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
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: const Color(0xFF98A2B3),
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
                          color: notification.type == NotificationType.company
                              ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                              : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notification.type == NotificationType.company
                              ? 'Company'
                              : 'News',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: notification.type == NotificationType.company
                                ? const Color(0xFF007AFF)
                                : const Color(0xFF10B981),
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
      ),
    );
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

enum NotificationType { company, news }

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
    return NotificationItem(
      id: json['id'],
      type: json['type'] == 'company'
          ? NotificationType.company
          : NotificationType.news,
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'],
    );
  }

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });
}
