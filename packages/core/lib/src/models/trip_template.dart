import 'trip.dart';

/// Model representing a saved trip template
class TripTemplate {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final Trip templateData; // The actual trip data stored as JSON
  final bool isFavorite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TripTemplate({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.templateData,
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
  });

  factory TripTemplate.fromJson(Map<String, dynamic> json) {
    return TripTemplate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      templateData: Trip.fromJson(
        json['template_data'] as Map<String, dynamic>,
      ),
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'template_data': templateData.toJson(),
      'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  TripTemplate copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    Trip? templateData,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      templateData: templateData ?? this.templateData,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
