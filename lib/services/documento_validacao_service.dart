import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/documento_validacao.dart';
import 'package:hubfrete/services/notification_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Service para gerenciar documentos com validação de vencimento
class DocumentoValidacaoService {

  /// Buscar documentos de um motorista
  Future<List<DocumentoValidacao>> getByMotoristaId(String motoristaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('documentos_validacao')
          .select()
          .eq('motorista_id', motoristaId)
          .order('data_vencimento', ascending: true);
      return (data as List).map((json) => DocumentoValidacao.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get documentos motorista error: $e');
      return [];
    }
  }

  /// Buscar documentos de um veículo
  Future<List<DocumentoValidacao>> getByVeiculoId(String veiculoId) async {
    try {
      final data = await SupabaseConfig.client
          .from('documentos_validacao')
          .select()
          .eq('veiculo_id', veiculoId)
          .order('data_vencimento', ascending: true);
      return (data as List).map((json) => DocumentoValidacao.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get documentos veiculo error: $e');
      return [];
    }
  }

  /// Buscar documentos de uma carroceria
  Future<List<DocumentoValidacao>> getByCarroceriaId(String carroceriaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('documentos_validacao')
          .select()
          .eq('carroceria_id', carroceriaId)
          .order('data_vencimento', ascending: true);
      return (data as List).map((json) => DocumentoValidacao.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get documentos carroceria error: $e');
      return [];
    }
  }

  /// Criar novo documento
  Future<DocumentoValidacao?> create({
    String? motoristaId,
    String? veiculoId,
    String? carroceriaId,
    required TipoDocumento tipo,
    required String numero,
    String? url,
    DateTime? dataEmissao,
    DateTime? dataVencimento,
  }) async {
    try {
      final now = DateTime.now();
      final doc = DocumentoValidacao(
        id: '',
        motoristaId: motoristaId,
        veiculoId: veiculoId,
        carroceriaId: carroceriaId,
        tipo: tipo,
        numero: numero,
        url: url,
        dataEmissao: dataEmissao,
        dataVencimento: dataVencimento,
        status: StatusDocumento.pendente,
        createdAt: now,
        updatedAt: now,
      );

      final data = await SupabaseConfig.client
          .from('documentos_validacao')
          .insert(doc.toJson())
          .select()
          .single();

      return DocumentoValidacao.fromJson(data);
    } catch (e) {
      debugPrint('Create documento error: $e');
      return null;
    }
  }

  /// Atualizar documento
  Future<bool> update(String docId, {
    String? numero,
    String? url,
    DateTime? dataEmissao,
    DateTime? dataVencimento,
  }) async {
    try {
      final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
      if (numero != null) updates['numero'] = numero;
      if (url != null) updates['url'] = url;
      if (dataEmissao != null) updates['data_emissao'] = dataEmissao.toIso8601String();
      if (dataVencimento != null) updates['data_vencimento'] = dataVencimento.toIso8601String();

      await SupabaseConfig.client.from('documentos_validacao').update(updates).eq('id', docId);
      return true;
    } catch (e) {
      debugPrint('Update documento error: $e');
      return false;
    }
  }

  /// Deletar documento
  Future<bool> delete(String docId) async {
    try {
      await SupabaseConfig.client.from('documentos_validacao').delete().eq('id', docId);
      return true;
    } catch (e) {
      debugPrint('Delete documento error: $e');
      return false;
    }
  }

  /// Buscar documentos vencidos ou próximos do vencimento
  Future<List<DocumentoValidacao>> getDocumentosComAlerta({String? motoristaId}) async {
    try {
      var query = SupabaseConfig.client
          .from('documentos_validacao')
          .select()
          .inFilter('status', ['vence_30_dias', 'vence_15_dias', 'vence_7_dias', 'vencido']);

      if (motoristaId != null) {
        query = query.eq('motorista_id', motoristaId);
      }

      final data = await query.order('data_vencimento', ascending: true);
      return (data as List).map((json) => DocumentoValidacao.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get documentos com alerta error: $e');
      return [];
    }
  }

  /// Enviar notificações de documentos próximos do vencimento
  Future<void> enviarAlertas(String motoristaId) async {
    try {
      final docs = await getDocumentosComAlerta(motoristaId: motoristaId);
      for (final doc in docs) {
        if (doc.status == StatusDocumento.vence7Dias || doc.status == StatusDocumento.vencido) {
          await NotificationService.instance.showTrackingNotification(
            title: 'Documento ${doc.status == StatusDocumento.vencido ? 'Vencido' : 'Prestes a Vencer'}',
            message: '${doc.tipo.displayName} ${doc.numero} - ${doc.status.displayName}',
            motoristaId: motoristaId,
          );
        }
      }
    } catch (e) {
      debugPrint('Enviar alertas documentos error: $e');
    }
  }

  /// Verificar se motorista/veículo está bloqueado por documentos vencidos
  Future<bool> isPodeDirigir(String motoristaId) async {
    try {
      final docs = await getByMotoristaId(motoristaId);
      // Bloquear se CNH vencida
      final cnh = docs.where((d) => d.tipo == TipoDocumento.cnh).firstOrNull;
      if (cnh != null && cnh.statusCalculado == StatusDocumento.vencido) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Check pode dirigir error: $e');
      return true;
    }
  }

  Future<bool> isVeiculoLiberado(String veiculoId) async {
    try {
      final docs = await getByVeiculoId(veiculoId);
      // Bloquear se CRLV, ANTT ou Seguro vencidos
      final docsObrigatorios = docs.where((d) =>
          d.tipo == TipoDocumento.crlv ||
          d.tipo == TipoDocumento.antt ||
          d.tipo == TipoDocumento.seguro);
      
      for (final doc in docsObrigatorios) {
        if (doc.statusCalculado == StatusDocumento.vencido) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Check veiculo liberado error: $e');
      return true;
    }
  }
}
