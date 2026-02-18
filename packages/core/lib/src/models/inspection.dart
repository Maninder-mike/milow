import 'inspection_defect.dart';

class Inspection {
  final String id;
  final String driverId;
  final String vehicleId;
  final String? trailerId;
  final String type; // 'pre-trip', 'post-trip'
  final double odometer;
  final String? location;
  final DateTime signedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final List<InspectionDefect> defects;

  final String? signaturePath;
  final String? signatureUrl;

  Inspection({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    this.trailerId,
    required this.type,
    required this.odometer,
    this.location,
    required this.signedAt,
    this.createdAt,
    this.updatedAt,
    this.notes,
    this.defects = const [],
    this.isSynced = false,
    this.signaturePath,
    this.signatureUrl,
  });

  bool get hasDefects => defects.isNotEmpty;
  final bool isSynced;
  bool get isSafeToDrive => defects.every((d) => d.isRepaired);

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      vehicleId: json['vehicle_id'] as String,
      trailerId: json['trailer_id'] as String?,
      type: json['type'] as String,
      odometer: (json['odometer'] as num).toDouble(),
      location: json['location'] as String?,
      signedAt: DateTime.parse(json['signed_at'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      notes: json['notes'] as String?,
      defects:
          (json['defects'] as List<dynamic>?)
              ?.map((e) => InspectionDefect.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isSynced: json['is_synced'] as bool? ?? false,
      signaturePath: json['signature_path'] as String?,
      signatureUrl: json['signature_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'trailer_id': trailerId,
      'type': type,
      'odometer': odometer,
      'location': location,
      'signed_at': signedAt.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'notes': notes,
      'defects': defects.map((e) => e.toJson()).toList(),
      'is_synced': isSynced,
      'signature_path': signaturePath,
      'signature_url': signatureUrl,
    };
  }

  Inspection copyWith({
    String? id,
    String? driverId,
    String? vehicleId,
    String? trailerId,
    String? type,
    double? odometer,
    String? location,
    DateTime? signedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    List<InspectionDefect>? defects,
    bool? isSynced,
    String? signaturePath,
    String? signatureUrl,
  }) {
    return Inspection(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      trailerId: trailerId ?? this.trailerId,
      type: type ?? this.type,
      odometer: odometer ?? this.odometer,
      location: location ?? this.location,
      signedAt: signedAt ?? this.signedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      defects: defects ?? this.defects,
      isSynced: isSynced ?? this.isSynced,
      signaturePath: signaturePath ?? this.signaturePath,
      signatureUrl: signatureUrl ?? this.signatureUrl,
    );
  }
}
