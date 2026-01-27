import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/services/location_tracking_service.dart';
import 'package:motohub/services/notification_service.dart';
import 'package:motohub/services/storage_upload_service.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing entregas (deliveries)
class EntregaService {
  static const List<String> _documentsBucketFallback = [
    StorageUploadService.documentsBucket,
    'notas-fiscais',
    'documents',
    'comprovantes',
    'documentos',
  ];

  /// Aceitar uma carga automaticamente.
  ///
  /// Fluxo:
  /// - cria um registro em `entregas`
  /// - debita o peso do `peso_disponivel_kg` da carga (e atualiza status)
  /// - debita o peso da capacidade do veículo
  ///
  /// Tudo executado de forma transacional no Supabase via Edge Function.
  Future<Entrega?> acceptCargaAutomatico({
    required String cargaId,
    required String veiculoId,
    String? carroceriaId,
    required double pesoKg,
  }) async {
    try {
      debugPrint('EntregaService.acceptCargaAutomatico: cargaId=$cargaId veiculoId=$veiculoId pesoKg=$pesoKg carroceriaId=$carroceriaId');

      final response = await SupabaseConfig.client.functions.invoke(
        'accept_carga',
        body: {
          'carga_id': cargaId,
          'veiculo_id': veiculoId,
          'carroceria_id': carroceriaId,
          'peso_kg': pesoKg,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final entregaJson = data['entrega'];
        if (entregaJson is Map<String, dynamic>) {
          return Entrega.fromJson(entregaJson);
        }
      }

      debugPrint('EntregaService.acceptCargaAutomatico: unexpected response data=$data');
      return null;
    } on FunctionException catch (e) {
      debugPrint('EntregaService.acceptCargaAutomatico function error: ${e.details}');
      rethrow;
    } catch (e) {
      debugPrint('EntregaService.acceptCargaAutomatico error: $e');
      rethrow;
    }
  }

  /// Get motorista's entregas
  Future<List<Entrega>> getMotoristaEntregas(String motoristaId, {bool activeOnly = false}) async {
    try {
      var query = SupabaseConfig.client
          .from('entregas')
          .select('''
            *,
            carga:carga_id(
              *,
              origem:enderecos_carga!cargas_endereco_origem_id_fkey(*),
              destino:enderecos_carga!cargas_endereco_destino_id_fkey(*)
            )
          ''')
          .eq('motorista_id', motoristaId);

      if (activeOnly) {
        query = query.inFilter('status', [
          StatusEntrega.aguardando.value,
          StatusEntrega.saiuParaColeta.value,
          StatusEntrega.saiuParaEntrega.value,
        ]);
      }

      final data = await query.order('created_at', ascending: false);
      return (data as List).map((json) => Entrega.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get motorista entregas error: $e');
      rethrow;
    }
  }

  /// Get entrega by ID
  Future<Entrega?> getEntregaById(String entregaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('entregas')
          .select('''
            *,
            carga:carga_id(
              *,
              origem:enderecos_carga!cargas_endereco_origem_id_fkey(*),
              destino:enderecos_carga!cargas_endereco_destino_id_fkey(*)
            )
          ''')
          .eq('id', entregaId)
          .maybeSingle();

      if (data == null) return null;
      return Entrega.fromJson(data);
    } catch (e) {
      debugPrint('Get entrega by ID error: $e');
      return null;
    }
  }

  /// Update entrega status with optional checklist
  Future<void> updateStatus(String entregaId, StatusEntrega status, {Map<String, dynamic>? additionalData, Map<String, dynamic>? checklistData}) async {
    try {
      final updates = <String, dynamic>{
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add timestamp fields based on status
      // No novo enum, consideramos que a coleta foi concluída quando o motorista
      // sai para entrega.
      if (status == StatusEntrega.saiuParaEntrega) {
        updates['coletado_em'] = DateTime.now().toIso8601String();
      } else if (status == StatusEntrega.entregue) {
        updates['entregue_em'] = DateTime.now().toIso8601String();
      }

      if (additionalData != null) {
        updates.addAll(additionalData);
      }

      if (checklistData != null) {
        updates['checklist_veiculo'] = checklistData;
      }

      await SupabaseConfig.client
          .from('entregas')
          .update(updates)
          .eq('id', entregaId);

      // Insert tracking history
      await _insertTrackingHistory(entregaId, status, additionalData?['observacao']);

      // Auto-start/stop tracking based on status
      await _handleTrackingForStatus(entregaId, status);

      // Send notification
      await _sendStatusNotification(status);
    } catch (e) {
      debugPrint('Update entrega status error: $e');
      rethrow;
    }
  }

  /// Handle automatic tracking start/stop based on status
  Future<void> _handleTrackingForStatus(String entregaId, StatusEntrega status) async {
    try {
      final entrega = await getEntregaById(entregaId);
      if (entrega == null || entrega.motoristaId == null) return;

      // Start tracking when collection begins
      if (status == StatusEntrega.saiuParaColeta) {
        debugPrint('🚀 Auto-starting tracking for entrega $entregaId');
        final ok = await LocationTrackingService.instance.startTracking(
          entregaId,
          entrega.motoristaId!,
        );
        if (!ok) {
          debugPrint('⚠️ Tracking not started (missing permissions or other issue) for entrega $entregaId');
        }
      }
      // Stop tracking when delivery is completed or cancelled
      else if ([
        StatusEntrega.entregue,
        StatusEntrega.cancelada,
        StatusEntrega.problema,
      ].contains(status)) {
        debugPrint('🛑 Auto-stopping tracking for entrega $entregaId');
        await LocationTrackingService.instance.stopTracking();
      }
    } catch (e) {
      debugPrint('Handle tracking for status error: $e');
    }
  }

  /// Send notification for status change
  Future<void> _sendStatusNotification(StatusEntrega status) async {
    try {
      String title = '';
      String message = '';

      switch (status) {
        case StatusEntrega.saiuParaColeta:
          title = '📦 Saiu para coleta';
          message = 'Rastreamento ativo durante a operação.';
          break;
        case StatusEntrega.saiuParaEntrega:
          title = '🚚 Saiu para entrega';
          message = 'Você está a caminho do destino.';
          break;
        case StatusEntrega.entregue:
          title = '🎉 Entrega Concluída';
          message = 'Entrega finalizada com sucesso!';
          break;
        default:
          return;
      }

      await NotificationService.instance.showDeliveryEvent(
        title: title,
        message: message,
        tipo: status.value,
      );
    } catch (e) {
      debugPrint('Send status notification error: $e');
    }
  }

  /// Insert tracking history
  Future<void> _insertTrackingHistory(String entregaId, StatusEntrega status, String? observacao) async {
    try {
      await SupabaseConfig.client.from('tracking_historico').insert({
        'entrega_id': entregaId,
        'status': status.value,
        'observacao': observacao,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Insert tracking history error: $e');
    }
  }

  /// Upload comprovante (POD) for coleta/entrega.
  ///
  /// Accepts images or PDFs and stores the public URL in the entrega record.
  Future<String> uploadComprovante(
    String entregaId, {
    required String originalFileName,
    required List<int> fileBytes,
    String? contentType,
    bool isColeta = false,
  }) async {
    try {
      final ext = _safeFileExtension(originalFileName);
      final fileName = '${entregaId}_${isColeta ? 'coleta' : 'entrega'}_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '' : '.$ext'}';
      // No Supabase, "pastas" são apenas prefixos no path.
      // Vamos padronizar canhotos em: notas-fiscais/canhotos/<arquivo>
      final storagePath = 'canhotos/$fileName';

      final publicUrl = await _uploadWithBucketFallback(
        path: storagePath,
        bytes: Uint8List.fromList(fileBytes),
        contentType: contentType,
      );

      // Update entrega with photo URL and canhoto_url
      final field = isColeta ? 'foto_comprovante_coleta' : 'foto_comprovante_entrega';
      final updates = {
        field: publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Se for comprovante de entrega (não coleta), salvar também em canhoto_url
      if (!isColeta) {
        updates['canhoto_url'] = publicUrl;
      }
      
      await SupabaseConfig.client
          .from('entregas')
          .update(updates)
          .eq('id', entregaId);

      return publicUrl;
    } catch (e) {
      debugPrint('Upload comprovante error: $e');
      rethrow;
    }
  }

  Future<String> _uploadWithBucketFallback({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    StorageException? lastStorage;
    for (final bucket in _documentsBucketFallback.toSet()) {
      try {
        return await const StorageUploadService().uploadPublic(
          bucket: bucket,
          path: path,
          bytes: bytes,
          contentType: contentType,
        );
      } on StorageException catch (e) {
        lastStorage = e;
        if (e.statusCode == 404) {
          debugPrint('Storage bucket "$bucket" not found (404). Trying next candidate...');
          continue;
        }
        rethrow;
      }
    }

    debugPrint(
      'Nenhum bucket de Storage encontrado para comprovantes. '
      'Crie/renomeie o bucket (ex: "notas-fiscais") no Supabase Storage ou ajuste o nome no app.',
    );
    final msg = lastStorage?.message ?? 'Bucket not found';
    throw StorageException(
      msg,
      statusCode: (lastStorage?.statusCode ?? 404).toString(),
      error: (lastStorage?.error ?? msg).toString(),
    );
  }

  String _safeFileExtension(String fileName) {
    final lower = fileName.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot == -1 || dot == lower.length - 1) return '';
    final ext = lower.substring(dot + 1);
    // Only allow common extensions we support.
    const allowed = {'pdf', 'png', 'jpg', 'jpeg', 'webp'};
    return allowed.contains(ext) ? ext : '';
  }

  /// Update entrega with receiver information
  Future<void> updateReceiverInfo(String entregaId, {
    required String nomeRecebedor,
    String? documentoRecebedor,
    String? observacoes,
  }) async {
    try {
      await SupabaseConfig.client
          .from('entregas')
          .update({
            'nome_recebedor': nomeRecebedor,
            'documento_recebedor': documentoRecebedor,
            'observacoes': observacoes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', entregaId);
    } catch (e) {
      debugPrint('Update receiver info error: $e');
      rethrow;
    }
  }

  /// Get tracking history for entrega
  Future<List<Map<String, dynamic>>> getTrackingHistory(String entregaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('tracking_historico')
          .select()
          .eq('entrega_id', entregaId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Get tracking history error: $e');
      return [];
    }
  }

  /// Generate signed URL for CT-e document with temporary permission
  /// 
  /// Takes a storage path or URL and returns a signed URL valid for 1 hour.
  /// This bypasses RLS policies on the private storage bucket.
  /// 
  /// Supported formats:
  /// - Full URL: "https://xxx.supabase.co/storage/v1/object/public/notas-fiscais/ctes/user123/file.pdf"
  /// - Relative path: "ctes/user123/file.pdf"
  /// - Path with bucket: "notas-fiscais/ctes/user123/file.pdf"
  Future<String?> getCteSignedUrl(String? cteUrl) async {
    if (cteUrl == null || cteUrl.trim().isEmpty) return null;

    try {
      String filePath = cteUrl.trim();
      const bucketName = 'notas-fiscais';

      // Extract path from full URL if provided
      if (filePath.startsWith('http')) {
        final match = RegExp(r'notas-fiscais/(.+)').firstMatch(filePath);
        if (match != null) {
          filePath = match.group(1)!;
        } else {
          // Try generic bucket extraction
          final uri = Uri.tryParse(filePath);
          if (uri != null) {
            final segments = uri.pathSegments;
            final bucketIndex = segments.indexOf(bucketName);
            if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
              filePath = segments.sublist(bucketIndex + 1).join('/');
            } else {
              debugPrint('Failed to extract path from URL: $filePath');
              return null;
            }
          }
        }
      } else if (filePath.startsWith('$bucketName/')) {
        // Remove bucket prefix if present
        filePath = filePath.substring(bucketName.length + 1);
      }

      debugPrint('Generating signed URL for: $bucketName/$filePath');

      // Generate signed URL valid for 1 hour (3600 seconds)
      final signedUrl = await SupabaseConfig.client.storage
          .from(bucketName)
          .createSignedUrl(filePath, 3600);

      debugPrint('Signed URL generated successfully');
      return signedUrl;
    } catch (e) {
      debugPrint('Generate CT-e signed URL error: $e');
      return null;
    }
  }
}
