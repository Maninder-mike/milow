class InspectionDefect {
  final String id;
  final String inspectionId;
  final String category; // 'brakes', 'lights', 'tires', etc.
  final String
  item; // Specific item name (e.g., 'Air Compressor', 'Headlights')
  final String? comment;
  final bool isRepaired;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InspectionDefect({
    required this.id,
    required this.inspectionId,
    required this.category,
    required this.item,
    this.comment,
    this.isRepaired = false,
    this.createdAt,
    this.updatedAt,
  });

  factory InspectionDefect.fromJson(Map<String, dynamic> json) {
    return InspectionDefect(
      id: json['id'] as String,
      inspectionId: json['inspection_id'] as String,
      category: json['category'] as String,
      item: json['item'] as String,
      comment: json['comment'] as String?,
      isRepaired: json['is_repaired'] as bool? ?? false,
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
      'inspection_id': inspectionId,
      'category': category,
      'item': item,
      'comment': comment,
      'is_repaired': isRepaired,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  InspectionDefect copyWith({
    String? id,
    String? inspectionId,
    String? category,
    String? item,
    String? comment,
    bool? isRepaired,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InspectionDefect(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      category: category ?? this.category,
      item: item ?? this.item,
      comment: comment ?? this.comment,
      isRepaired: isRepaired ?? this.isRepaired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
