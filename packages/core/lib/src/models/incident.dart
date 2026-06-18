import 'dart:convert';

class Incident {
  final String id;
  final String userId;
  final String? companyId;
  final String? tripId;
  final DateTime incidentDate;
  final String? location;
  final String description;
  final String? policeReportNumber;
  final String? policeDepartment;
  final Map<String, dynamic> thirdPartyInfo;
  final List<String> photos;
  final DateTime createdAt;
  final DateTime updatedAt;

  Incident({
    required this.id,
    required this.userId,
    this.companyId,
    this.tripId,
    required this.incidentDate,
    this.location,
    required this.description,
    this.policeReportNumber,
    this.policeDepartment,
    this.thirdPartyInfo = const {},
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    List<String> parsePhotos(dynamic photosJson) {
      if (photosJson == null) return [];
      if (photosJson is String) {
        try {
          final decoded = jsonDecode(photosJson);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      } else if (photosJson is List) {
        return photosJson.map((e) => e.toString()).toList();
      }
      return [];
    }

    Map<String, dynamic> parseThirdPartyInfo(dynamic info) {
      if (info == null) return {};
      if (info is String) {
        try {
          return jsonDecode(info) as Map<String, dynamic>;
        } catch (_) {}
      } else if (info is Map) {
        return Map<String, dynamic>.from(info);
      }
      return {};
    }

    return Incident(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      companyId: json['company_id'] as String?,
      tripId: json['trip_id'] as String?,
      incidentDate: DateTime.parse(json['incident_date'] as String),
      location: json['location'] as String?,
      description: json['description'] as String,
      policeReportNumber: json['police_report_number'] as String?,
      policeDepartment: json['police_department'] as String?,
      thirdPartyInfo: parseThirdPartyInfo(json['third_party_info']),
      photos: parsePhotos(json['photos']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (companyId != null) 'company_id': companyId,
      if (tripId != null) 'trip_id': tripId,
      'incident_date': incidentDate.toUtc().toIso8601String(),
      if (location != null) 'location': location,
      'description': description,
      if (policeReportNumber != null) 'police_report_number': policeReportNumber,
      if (policeDepartment != null) 'police_department': policeDepartment,
      'third_party_info': thirdPartyInfo,
      'photos': photos,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Incident copyWith({
    String? id,
    String? userId,
    String? companyId,
    String? tripId,
    DateTime? incidentDate,
    String? location,
    String? description,
    String? policeReportNumber,
    String? policeDepartment,
    Map<String, dynamic>? thirdPartyInfo,
    List<String>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Incident(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      tripId: tripId ?? this.tripId,
      incidentDate: incidentDate ?? this.incidentDate,
      location: location ?? this.location,
      description: description ?? this.description,
      policeReportNumber: policeReportNumber ?? this.policeReportNumber,
      policeDepartment: policeDepartment ?? this.policeDepartment,
      thirdPartyInfo: thirdPartyInfo ?? this.thirdPartyInfo,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
