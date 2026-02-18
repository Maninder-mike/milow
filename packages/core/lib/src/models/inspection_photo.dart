import 'package:json_annotation/json_annotation.dart';

part 'inspection_photo.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class InspectionPhoto {
  final String id;
  final String defectId;
  final String localPath;
  final String? remoteUrl;
  final DateTime createdAt;

  InspectionPhoto({
    required this.id,
    required this.defectId,
    required this.localPath,
    this.remoteUrl,
    required this.createdAt,
  });

  factory InspectionPhoto.fromJson(Map<String, dynamic> json) =>
      _$InspectionPhotoFromJson(json);

  Map<String, dynamic> toJson() => _$InspectionPhotoToJson(this);
}
