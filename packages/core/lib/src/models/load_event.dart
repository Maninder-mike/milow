import 'package:flutter/foundation.dart';

enum LoadEventType {
  assigned,
  accepted,
  rejected,
  enRoute,
  arrived,
  completed,
  statusChanged,
  noteAdded,
  documentAttached,
  checkCall;

  static LoadEventType fromString(String val) {
    switch (val) {
      case 'assigned':
        return LoadEventType.assigned;
      case 'accepted':
        return LoadEventType.accepted;
      case 'rejected':
        return LoadEventType.rejected;
      case 'enRoute':
        return LoadEventType.enRoute;
      case 'arrived':
        return LoadEventType.arrived;
      case 'completed':
        return LoadEventType.completed;
      case 'status_changed':
        return LoadEventType.statusChanged;
      case 'note_added':
        return LoadEventType.noteAdded;
      case 'document_attached':
        return LoadEventType.documentAttached;
      case 'check_call':
        return LoadEventType.checkCall;
      default:
        throw ArgumentError('Unknown LoadEventType: $val');
    }
  }

  String toJson() {
    switch (this) {
      case LoadEventType.assigned:
        return 'assigned';
      case LoadEventType.accepted:
        return 'accepted';
      case LoadEventType.rejected:
        return 'rejected';
      case LoadEventType.enRoute:
        return 'enRoute';
      case LoadEventType.arrived:
        return 'arrived';
      case LoadEventType.completed:
        return 'completed';
      case LoadEventType.statusChanged:
        return 'status_changed';
      case LoadEventType.noteAdded:
        return 'note_added';
      case LoadEventType.documentAttached:
        return 'document_attached';
      case LoadEventType.checkCall:
        return 'check_call';
    }
  }
}

class LoadEvent {
  final String id;
  final String loadId;
  final String companyId;
  final String actorId;
  final LoadEventType eventType;
  final Map<String, dynamic> eventData;
  final DateTime createdAt;

  const LoadEvent({
    required this.id,
    required this.loadId,
    required this.companyId,
    required this.actorId,
    required this.eventType,
    required this.eventData,
    required this.createdAt,
  });

  factory LoadEvent.fromJson(Map<String, dynamic> json) {
    return LoadEvent(
      id: json['id'] as String,
      loadId: json['load_id'] as String,
      companyId: json['company_id'] as String,
      actorId: json['actor_id'] as String,
      eventType: LoadEventType.fromString(json['event_type'] as String),
      eventData: json['event_data'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'load_id': loadId,
      'company_id': companyId,
      'actor_id': actorId,
      'event_type': eventType.toJson(),
      'event_data': eventData,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LoadEvent copyWith({
    String? id,
    String? loadId,
    String? companyId,
    String? actorId,
    LoadEventType? eventType,
    Map<String, dynamic>? eventData,
    DateTime? createdAt,
  }) {
    return LoadEvent(
      id: id ?? this.id,
      loadId: loadId ?? this.loadId,
      companyId: companyId ?? this.companyId,
      actorId: actorId ?? this.actorId,
      eventType: eventType ?? this.eventType,
      eventData: eventData ?? this.eventData,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is LoadEvent &&
      other.id == id &&
      other.loadId == loadId &&
      other.companyId == companyId &&
      other.actorId == actorId &&
      other.eventType == eventType &&
      mapEquals(other.eventData, eventData) &&
      other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      loadId.hashCode ^
      companyId.hashCode ^
      actorId.hashCode ^
      eventType.hashCode ^
      eventData.hashCode ^
      createdAt.hashCode;
  }
}
