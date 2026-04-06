import 'package:flutter/foundation.dart';

enum CheckCallType {
  location('location'),
  temperature('temperature'),
  weight('weight'),
  eta('eta'),
  custom('custom');

  final String value;
  const CheckCallType(this.value);

  factory CheckCallType.fromValue(String value) {
    return CheckCallType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CheckCallType.custom,
    );
  }

  String get label {
    switch (this) {
      case CheckCallType.location: return 'Location Share';
      case CheckCallType.temperature: return 'Temperature Reading';
      case CheckCallType.weight: return 'Weight Scale';
      case CheckCallType.eta: return 'ETA Update';
      case CheckCallType.custom: return 'Custom Question';
    }
  }
}

enum CheckCallStatus {
  pending('pending'),
  completed('completed'),
  expired('expired');

  final String value;
  const CheckCallStatus(this.value);

  factory CheckCallStatus.fromValue(String value) {
    return CheckCallStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CheckCallStatus.pending,
    );
  }
}

class CheckCall {
  final String id;
  final String loadId;
  final String companyId;
  final String driverId;
  final String? requesterId;
  final CheckCallType type;
  final CheckCallStatus status;
  final String prompt;
  final Map<String, dynamic>? options;
  final Map<String, dynamic>? responseData;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;

  const CheckCall({
    required this.id,
    required this.loadId,
    required this.companyId,
    required this.driverId,
    this.requesterId,
    required this.type,
    required this.status,
    required this.prompt,
    this.options,
    this.responseData,
    required this.createdAt,
    this.completedAt,
    this.expiresAt,
  });

  factory CheckCall.fromJson(Map<String, dynamic> json) {
    return CheckCall(
      id: json['id'] as String,
      loadId: json['load_id'] as String,
      companyId: json['company_id'] as String,
      driverId: json['driver_id'] as String,
      requesterId: json['requester_id'] as String?,
      type: CheckCallType.fromValue(json['type'] as String),
      status: CheckCallStatus.fromValue(json['status'] as String),
      prompt: json['prompt'] as String,
      options: json['options'] as Map<String, dynamic>?,
      responseData: json['response_data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'load_id': loadId,
      'company_id': companyId,
      'driver_id': driverId,
      'requester_id': requesterId,
      'type': type.value,
      'status': status.value,
      'prompt': prompt,
      'options': options,
      'response_data': responseData,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is CheckCall &&
      other.id == id &&
      other.loadId == loadId &&
      other.companyId == companyId &&
      other.driverId == driverId &&
      other.requesterId == requesterId &&
      other.type == type &&
      other.status == status &&
      other.prompt == prompt &&
      mapEquals(other.options, options) &&
      mapEquals(other.responseData, responseData);
  }

  @override
  int get hashCode {
    return id.hashCode ^
      loadId.hashCode ^
      companyId.hashCode ^
      driverId.hashCode ^
      requesterId.hashCode ^
      type.hashCode ^
      status.hashCode ^
      prompt.hashCode ^
      options.hashCode ^
      responseData.hashCode;
  }
}
