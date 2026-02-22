import 'package:freezed_annotation/freezed_annotation.dart';

part 'inspection_photo.freezed.dart';
part 'inspection_photo.g.dart';

@freezed
abstract class InspectionPhoto with _$InspectionPhoto {
  const factory InspectionPhoto({
    required String id,
    @JsonKey(name: 'defect_id') required String defectId,
    @JsonKey(name: 'local_path') String? localPath,
    @JsonKey(name: 'remote_url') String? remoteUrl,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _InspectionPhoto;

  factory InspectionPhoto.fromJson(Map<String, dynamic> json) =>
      _$InspectionPhotoFromJson(json);
}
