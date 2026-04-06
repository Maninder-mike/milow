import 'package:milow_core/src/models/trip_document.dart'; // To reuse DocumentStatus and TripDocumentType, or re-export

class LoadDocument {
  final String? id;
  final String loadId;
  final String? stopId;
  final String userId;
  final String? companyId;
  final TripDocumentType documentType;
  final String filePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? notes;
  final DocumentStatus status;
  final String? reviewNotes;
  final DateTime? createdAt;

  LoadDocument({
    required this.loadId,
    this.stopId,
    required this.documentType,
    required this.filePath,
    this.id,
    required this.userId,
    this.companyId,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.notes,
    this.status = DocumentStatus.pending,
    this.reviewNotes,
    this.createdAt,
  });

  factory LoadDocument.fromJson(Map<String, dynamic> json) {
    return LoadDocument(
      id: json['id'] as String?,
      loadId: json['load_id'] as String,
      stopId: json['stop_id'] as String?,
      userId: json['driver_id'] as String? ?? json['user_id'] as String? ?? '',
      companyId: json['company_id'] as String?,
      documentType: TripDocumentType.fromValue(json['document_type'] as String? ?? 'other'),
      filePath: json['file_path'] as String? ?? json['url'] as String? ?? '',
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      notes: json['notes'] as String?,
      status: DocumentStatus.fromValue(json['status'] as String? ?? 'pending'),
      reviewNotes: json['review_notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'load_id': loadId,
      if (stopId != null) 'stop_id': stopId,
      'driver_id': userId,
      if (companyId != null) 'company_id': companyId,
      'document_type': documentType.value,
      'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (notes != null) 'notes': notes,
      'status': status.name,
      if (reviewNotes != null) 'review_notes': reviewNotes,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }
}
