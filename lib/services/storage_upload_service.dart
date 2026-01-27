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
  /// Bucket padrão para documentos (CTe, canhotos, etc).
  ///
  /// Ajustado para o nome real do seu projeto no Supabase Storage.
  static const String documentsBucket = 'notas-fiscais';
  static const String checklistFolder = 'checklist';

  const StorageUploadService();

  /// Upload de foto do checklist do veículo.
  ///
  /// Salva em: notas-fiscais/checklist/{motoristaId}/{arquivo}
  Future<String> uploadChecklistPhoto({
    required String motoristaId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final fileName = 'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$checklistFolder/$motoristaId/$fileName';
    return uploadPublic(
      bucket: documentsBucket,
      path: path,
      bytes: bytes,
      contentType: contentType,
    );
  }

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
