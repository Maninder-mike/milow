import 'package:json_annotation/json_annotation.dart';

part 'detention.g.dart';

@JsonSerializable()
class Detention {
  final Duration duration;
  final String approverName;
  final String? notes;
  final bool isLayover;
  final DateTime updatedAt;

  Detention({
    required this.duration,
    required this.approverName,
    this.notes,
    this.isLayover = false,
    required this.updatedAt,
  });

  factory Detention.fromJson(Map<String, dynamic> json) =>
      _$DetentionFromJson(json);

  Map<String, dynamic> toJson() => _$DetentionToJson(this);
}
