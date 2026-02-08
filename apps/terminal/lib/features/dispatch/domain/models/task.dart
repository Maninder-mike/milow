import 'package:uuid/uuid.dart';

/// Task type classification for work breakdown
enum TaskType {
  pickup('pickup', 'Pickup'),
  delivery('delivery', 'Delivery'),
  inspection('inspection', 'Inspection'),
  documentation('documentation', 'Documentation'),
  customs('customs', 'Customs'),
  fuelStop('fuel_stop', 'Fuel Stop'),
  restBreak('rest_break', 'Rest Break'),
  equipmentCheck('equipment_check', 'Equipment Check'),
  weighStation('weigh_station', 'Weigh Station'),
  signatureCollection('signature_collection', 'Signature Collection'),
  photoCapture('photo_capture', 'Photo Capture'),
  other('other', 'Other');

  const TaskType(this.value, this.displayName);
  final String value;
  final String displayName;

  static TaskType fromString(String? value) {
    if (value == null) return TaskType.other;
    return TaskType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TaskType.other,
    );
  }

  String toJson() => value;

  /// Icon for display
  String get icon {
    switch (this) {
      case TaskType.pickup:
        return '📦';
      case TaskType.delivery:
        return '🚚';
      case TaskType.inspection:
        return '🔍';
      case TaskType.documentation:
        return '📄';
      case TaskType.customs:
        return '🛂';
      case TaskType.fuelStop:
        return '⛽';
      case TaskType.restBreak:
        return '☕';
      case TaskType.equipmentCheck:
        return '🔧';
      case TaskType.weighStation:
        return '⚖️';
      case TaskType.signatureCollection:
        return '✍️';
      case TaskType.photoCapture:
        return '📷';
      case TaskType.other:
        return '📋';
    }
  }
}

/// Task status for tracking progress
enum TaskStatus {
  pending('pending', 'Pending'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed'),
  skipped('skipped', 'Skipped'),
  cancelled('cancelled', 'Cancelled');

  const TaskStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static TaskStatus fromString(String? value) {
    if (value == null) return TaskStatus.pending;
    return TaskStatus.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TaskStatus.pending,
    );
  }

  String toJson() => value;

  bool get isComplete => this == completed || this == skipped;
  bool get isActive => this == inProgress;
  bool get isFailed => this == failed || this == cancelled;
  bool get isPending => this == pending;
}

/// Model for granular work breakdown within loads
class Task {
  final String id;
  final String companyId;
  final String? loadId;
  final String? stopId;
  final String? parentTaskId;
  final String title;
  final String? description;
  final TaskType taskType;
  final TaskStatus status;
  final int sequenceOrder;
  final String? assignedDriverId;
  final DateTime? scheduledAt;
  final DateTime? dueAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? estimatedDurationMinutes;
  final int? actualDurationMinutes;
  final String? locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final bool requiresSignature;
  final bool requiresPhoto;
  final bool requiresScan;
  final String? signatureUrl;
  final List<String> photoUrls;
  final String? notes;
  final Map<String, dynamic> completionData;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? completedBy;
  final List<Task> subTasks;

  Task({
    required this.id,
    required this.companyId,
    this.loadId,
    this.stopId,
    this.parentTaskId,
    required this.title,
    this.description,
    required this.taskType,
    required this.status,
    required this.sequenceOrder,
    this.assignedDriverId,
    this.scheduledAt,
    this.dueAt,
    this.startedAt,
    this.completedAt,
    this.estimatedDurationMinutes,
    this.actualDurationMinutes,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.requiresSignature = false,
    this.requiresPhoto = false,
    this.requiresScan = false,
    this.signatureUrl,
    this.photoUrls = const [],
    this.notes,
    this.completionData = const {},
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.completedBy,
    this.subTasks = const [],
  });

  /// Create a new task with generated UUID
  factory Task.create({
    required String companyId,
    String? loadId,
    String? stopId,
    String? parentTaskId,
    required String title,
    String? description,
    required TaskType taskType,
    int sequenceOrder = 0,
    String? assignedDriverId,
    DateTime? scheduledAt,
    DateTime? dueAt,
    int? estimatedDurationMinutes,
    String? locationName,
    String? locationAddress,
    double? latitude,
    double? longitude,
    bool requiresSignature = false,
    bool requiresPhoto = false,
    bool requiresScan = false,
    String? createdBy,
  }) {
    return Task(
      id: const Uuid().v4(),
      companyId: companyId,
      loadId: loadId,
      stopId: stopId,
      parentTaskId: parentTaskId,
      title: title,
      description: description,
      taskType: taskType,
      status: TaskStatus.pending,
      sequenceOrder: sequenceOrder,
      assignedDriverId: assignedDriverId,
      scheduledAt: scheduledAt,
      dueAt: dueAt,
      estimatedDurationMinutes: estimatedDurationMinutes,
      locationName: locationName,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      requiresSignature: requiresSignature,
      requiresPhoto: requiresPhoto,
      requiresScan: requiresScan,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      loadId: json['load_id'] as String?,
      stopId: json['stop_id'] as String?,
      parentTaskId: json['parent_task_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      taskType: TaskType.fromString(json['task_type'] as String?),
      status: TaskStatus.fromString(json['status'] as String?),
      sequenceOrder: json['sequence_order'] as int? ?? 0,
      assignedDriverId: json['assigned_driver_id'] as String?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      dueAt: json['due_at'] != null
          ? DateTime.parse(json['due_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      actualDurationMinutes: json['actual_duration_minutes'] as int?,
      locationName: json['location_name'] as String?,
      locationAddress: json['location_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      requiresSignature: json['requires_signature'] as bool? ?? false,
      requiresPhoto: json['requires_photo'] as bool? ?? false,
      requiresScan: json['requires_scan'] as bool? ?? false,
      signatureUrl: json['signature_url'] as String?,
      photoUrls:
          (json['photo_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      notes: json['notes'] as String?,
      completionData: json['completion_data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      completedBy: json['completed_by'] as String?,
      subTasks:
          (json['sub_tasks'] as List<dynamic>?)
              ?.map((t) => Task.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      if (loadId != null) 'load_id': loadId,
      if (stopId != null) 'stop_id': stopId,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      'title': title,
      if (description != null) 'description': description,
      'task_type': taskType.toJson(),
      'status': status.toJson(),
      'sequence_order': sequenceOrder,
      if (assignedDriverId != null) 'assigned_driver_id': assignedDriverId,
      if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
      if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
      if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (estimatedDurationMinutes != null)
        'estimated_duration_minutes': estimatedDurationMinutes,
      if (actualDurationMinutes != null)
        'actual_duration_minutes': actualDurationMinutes,
      if (locationName != null) 'location_name': locationName,
      if (locationAddress != null) 'location_address': locationAddress,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'requires_signature': requiresSignature,
      'requires_photo': requiresPhoto,
      'requires_scan': requiresScan,
      if (signatureUrl != null) 'signature_url': signatureUrl,
      if (photoUrls.isNotEmpty) 'photo_urls': photoUrls,
      if (notes != null) 'notes': notes,
      if (completionData.isNotEmpty) 'completion_data': completionData,
    };
  }

  Task copyWith({
    String? id,
    String? companyId,
    String? loadId,
    String? stopId,
    String? parentTaskId,
    String? title,
    String? description,
    TaskType? taskType,
    TaskStatus? status,
    int? sequenceOrder,
    String? assignedDriverId,
    DateTime? scheduledAt,
    DateTime? dueAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? estimatedDurationMinutes,
    int? actualDurationMinutes,
    String? locationName,
    String? locationAddress,
    double? latitude,
    double? longitude,
    bool? requiresSignature,
    bool? requiresPhoto,
    bool? requiresScan,
    String? signatureUrl,
    List<String>? photoUrls,
    String? notes,
    Map<String, dynamic>? completionData,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? completedBy,
    List<Task>? subTasks,
  }) {
    return Task(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      loadId: loadId ?? this.loadId,
      stopId: stopId ?? this.stopId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      status: status ?? this.status,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      dueAt: dueAt ?? this.dueAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      requiresSignature: requiresSignature ?? this.requiresSignature,
      requiresPhoto: requiresPhoto ?? this.requiresPhoto,
      requiresScan: requiresScan ?? this.requiresScan,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      notes: notes ?? this.notes,
      completionData: completionData ?? this.completionData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      completedBy: completedBy ?? this.completedBy,
      subTasks: subTasks ?? this.subTasks,
    );
  }

  /// Start the task
  Task start() {
    return copyWith(status: TaskStatus.inProgress, startedAt: DateTime.now());
  }

  /// Complete the task
  Task complete({String? notes, String? completedBy}) {
    final now = DateTime.now();
    return copyWith(
      status: TaskStatus.completed,
      completedAt: now,
      notes: notes ?? this.notes,
      completedBy: completedBy,
      actualDurationMinutes: startedAt != null
          ? now.difference(startedAt!).inMinutes
          : estimatedDurationMinutes,
    );
  }

  /// Skip the task
  Task skip({String? notes}) {
    return copyWith(
      status: TaskStatus.skipped,
      completedAt: DateTime.now(),
      notes: notes ?? this.notes,
    );
  }

  /// Fail the task
  Task fail({String? notes}) {
    return copyWith(
      status: TaskStatus.failed,
      completedAt: DateTime.now(),
      notes: notes ?? this.notes,
    );
  }

  /// Check if task has location
  bool get hasLocation => latitude != null && longitude != null;

  /// Check if task is a subtask
  bool get isSubTask => parentTaskId != null;

  /// Check if task has subtasks
  bool get hasSubTasks => subTasks.isNotEmpty;

  /// Get completion percentage for subtasks
  double get subTasksCompletionPercentage {
    if (subTasks.isEmpty) return 1.0;
    final completed = subTasks.where((t) => t.status.isComplete).length;
    return completed / subTasks.length;
  }

  /// Check if all requirements are met for completion
  bool get requirementsMet {
    if (requiresSignature && signatureUrl == null) return false;
    if (requiresPhoto && photoUrls.isEmpty) return false;
    return true;
  }

  /// Get duration display
  String get durationDisplay {
    final minutes = actualDurationMinutes ?? estimatedDurationMinutes;
    if (minutes == null) return '--';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0
        ? '${hours}h ${remainingMinutes}m'
        : '${hours}h';
  }
}
