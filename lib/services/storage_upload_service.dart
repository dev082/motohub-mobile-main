import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload helper for Supabase Storage.
///
/// Notes:
/// - Buckets must already exist in Supabase Storage.
/// - This service uploads binary data and returns a public URL.
class StorageUploadService {
  static const String vehicleBucket = 'veiculos';
  static const String trailerBucket = 'carrocerias';
  static const String documentsBucket = 'documentos';

  const StorageUploadService();

  Future<String> uploadPublic({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      await SupabaseConfig.client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return SupabaseConfig.client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('Storage upload error ($bucket/$path): $e');
      rethrow;
    }
  }
}
