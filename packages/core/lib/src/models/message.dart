import 'dart:convert';

/// Types of messages in the system
enum MessageType {
  text,
  image,
  quickAction,
  documentRef;

  String get value => name;

  static MessageType fromValue(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Payload for structured quick actions in chat
class QuickActionPayload {
  final String actionType; // e.g., 'request_eta', 'confirm_arrival', 'upload_pod'
  final String label;
  final String status; // 'pending', 'completed'
  final Map<String, dynamic>? metadata;

  QuickActionPayload({
    required this.actionType,
    required this.label,
    this.status = 'pending',
    this.metadata,
  });

  factory QuickActionPayload.fromJson(Map<String, dynamic> json) {
    return QuickActionPayload(
      actionType: json['actionType'] as String,
      label: json['label'] as String,
      status: json['status'] as String? ?? 'pending',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionType': actionType,
      'label': label,
      'status': status,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Model representing a message in a conversation
class Message {
  final String? id;
  final String? companyId;
  final String? loadId; // Scoped to a load
  final String senderId;
  final String? receiverId; // Null for load-scoped group chat
  final String content;
  final MessageType type;
  final String? attachmentUrl;
  final DateTime createdAt;

  // Metadata for UI
  final String? senderName;
  final String? senderRole;
  final String? senderAvatarUrl;

  Message({
    this.id,
    this.companyId,
    this.loadId,
    required this.senderId,
    this.receiverId,
    required this.content,
    this.type = MessageType.text,
    this.attachmentUrl,
    required this.createdAt,
    this.senderName,
    this.senderRole,
    this.senderAvatarUrl,
  });

  /// Get the structured payload if this is a quick action message
  QuickActionPayload? get quickActionPayload {
    if (type != MessageType.quickAction) return null;
    try {
      return QuickActionPayload.fromJson(jsonDecode(content));
    } catch (_) {
      return null;
    }
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    // Handle sender metadata if joined in Supabase query
    final senderMetadata = json['sender'] as Map<String, dynamic>?;

    return Message(
      id: json['id'] as String?,
      companyId: json['company_id'] as String?,
      loadId: json['load_id'] as String?,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String?,
      content: json['content'] as String? ?? '',
      type: MessageType.fromValue(json['message_type'] as String? ?? 'text'),
      attachmentUrl: json['attachment_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: senderMetadata?['full_name'] as String?,
      senderRole: senderMetadata?['role'] as String?,
      senderAvatarUrl: senderMetadata?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (loadId != null) 'load_id': loadId,
      'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      'content': content,
      'message_type': type.value,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Message copyWith({
    String? id,
    String? companyId,
    String? loadId,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    String? attachmentUrl,
    DateTime? createdAt,
    String? senderName,
    String? senderRole,
    String? senderAvatarUrl,
  }) {
    return Message(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      loadId: loadId ?? this.loadId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
    );
  }
}
