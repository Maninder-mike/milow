class QuickNote {
  final String id;
  final String? userId;
  final String? tripId;
  final String? title;
  final String? content;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuickNote({
    required this.id,
    this.userId,
    this.tripId,
    this.title,
    this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuickNote.fromJson(Map<String, dynamic> json) {
    return QuickNote(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      tripId: json['trip_id'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (tripId != null) 'trip_id': tripId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  QuickNote copyWith({
    String? id,
    String? userId,
    String? tripId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuickNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
