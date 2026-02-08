import 'package:flutter/foundation.dart';

enum NotificationType { info, success, warning, error }

@immutable
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.metadata,
    this.onTap,
    this.onDismiss,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    Map<String, dynamic>? metadata,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      onTap: onTap ?? this.onTap,
      onDismiss: onDismiss ?? this.onDismiss,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationItem &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        other.timestamp == timestamp &&
        other.type == type &&
        other.isRead == isRead &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        body.hashCode ^
        timestamp.hashCode ^
        type.hashCode ^
        isRead.hashCode ^
        metadata.hashCode;
  }
}
