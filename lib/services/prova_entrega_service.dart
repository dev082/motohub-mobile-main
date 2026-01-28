import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/prova_entrega.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Service para gerenciar Provas de Entrega (POD)
class ProvaEntregaService {
  /// Buscar prova de entrega por ID da entrega
  Future<ProvaEntrega?> getByEntregaId(String entregaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('provas_entrega')
          .select()
          .eq('entrega_id', entregaId)
          .maybeSingle();

      if (data == null) return null;
      return ProvaEntrega.fromJson(data);
    } catch (e) {
      debugPrint('Get prova entrega error: $e');
      return null;
    }
  }

  /// Criar nova prova de entrega
  Future<ProvaEntrega?> create({
    required String entregaId,
    String? assinaturaUrl,
    List<String> fotosUrls = const [],
    required String nomeRecebedor,
    String? documentoRecebedor,
    required ChecklistProvaEntrega checklist,
    String? observacoes,
  }) async {
    try {
      final now = DateTime.now();
      final prova = ProvaEntrega(
        id: '',
        entregaId: entregaId,
        assinaturaUrl: assinaturaUrl,
        fotosUrls: fotosUrls,
        nomeRecebedor: nomeRecebedor,
        documentoRecebedor: documentoRecebedor,
        timestamp: now,
        checklist: checklist,
        observacoes: observacoes,
        createdAt: now,
      );

      final data = await SupabaseConfig.client
          .from('provas_entrega')
          .insert(prova.toJson())
          .select()
          .single();

      return ProvaEntrega.fromJson(data);
    } catch (e) {
      debugPrint('Create prova entrega error: $e');
      return null;
    }
  }

  /// Atualizar prova de entrega existente
  Future<bool> update(String provaId, {
    String? assinaturaUrl,
    List<String>? fotosUrls,
    String? nomeRecebedor,
    String? documentoRecebedor,
    ChecklistProvaEntrega? checklist,
    String? observacoes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (assinaturaUrl != null) updates['assinatura_url'] = assinaturaUrl;
      if (fotosUrls != null) updates['fotos_urls'] = fotosUrls;
      if (nomeRecebedor != null) updates['nome_recebedor'] = nomeRecebedor;
      if (documentoRecebedor != null) updates['documento_recebedor'] = documentoRecebedor;
      if (checklist != null) updates['checklist'] = checklist.toJson();
      if (observacoes != null) updates['observacoes'] = observacoes;

      await SupabaseConfig.client
          .from('provas_entrega')
          .update(updates)
          .eq('id', provaId);
      return true;
    } catch (e) {
      debugPrint('Update prova entrega error: $e');
      return false;
    }
  }

  /// Deletar prova de entrega
  Future<bool> delete(String provaId) async {
    try {
      await SupabaseConfig.client.from('provas_entrega').delete().eq('id', provaId);
      return true;
    } catch (e) {
      debugPrint('Delete prova entrega error: $e');
      return false;
    }
  }

  /// Validar se POD está completo (campos obrigatórios preenchidos)
  bool isProvaCompleta(ProvaEntrega prova) {
    return prova.assinaturaUrl != null &&
        prova.assinaturaUrl!.isNotEmpty &&
        prova.fotosUrls.isNotEmpty &&
        prova.nomeRecebedor.isNotEmpty;
  }

  /// Validar checklist (verificar se há problemas)
  bool hasProblemas(ChecklistProvaEntrega checklist) {
    return checklist.avariasConstatadas ||
        !checklist.lacreIntacto ||
        !checklist.quantidadeConferida ||
        !checklist.notaFiscalPresente;
  }
}
