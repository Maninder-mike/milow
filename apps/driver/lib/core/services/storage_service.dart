import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

/// Service to handle file storage and compression.
class StorageService {
  static const String _bucketName = 'receipts';
  static SupabaseClient get _client => Supabase.instance.client;

  /// Uploads a receipt image to Supabase Storage.
  ///
  /// Compresses the image to WebP format to save space/bandwidth.
  /// Returns the public URL of the uploaded file.
  static Future<String?> uploadReceipt(File file, String userId) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final path = '$userId/$fileName.webp'; // Force .webp extension

      // Compress image
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
            file.absolute.path,
            minWidth: 1024,
            minHeight: 1024,
            quality: 70,
            format: CompressFormat.webp,
          );

      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      debugPrint(
        '[StorageService] Compressed size: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB',
      );

      // Upload to Supabase
      await _client.storage
          .from(_bucketName)
          .uploadBinary(
            path,
            compressedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              upsert: false,
            ),
          );

      // Get Public URL
      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('[StorageService] Upload failed: $e');
      return null;
    }
  }
}
