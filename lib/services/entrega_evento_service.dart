import 'package:flutter/foundation.dart';
import 'package:motohub/models/entrega_evento.dart';
import 'package:motohub/services/notification_service.dart';
import 'package:motohub/supabase/supabase_config.dart';

/// Service para gerenciar eventos de entrega (timeline + auditoria)
class EntregaEventoService {
  /// Buscar todos os eventos de uma entrega (ordenados por timestamp)
  Future<List<EntregaEvento>> getEventosByEntrega(String entregaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('entrega_eventos')
          .select()
          .eq('entrega_id', entregaId)
          .order('timestamp', ascending: false);
      return (data as List).map((json) => EntregaEvento.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get eventos by entrega error: $e');
      return [];
    }
  }

  /// Criar um novo evento de entrega
  Future<EntregaEvento?> createEvento({
    required String entregaId,
    required TipoEventoEntrega tipo,
    String? observacao,
    double? latitude,
    double? longitude,
    String? userId,
    String? userNome,
    String? fotoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();
      final evento = EntregaEvento(
        id: '',
        entregaId: entregaId,
        tipo: tipo,
        timestamp: now,
        observacao: observacao,
        latitude: latitude,
        longitude: longitude,
        userId: userId,
        userNome: userNome,
        fotoUrl: fotoUrl,
        metadata: metadata,
        createdAt: now,
      );

      final data = await SupabaseConfig.client
          .from('entrega_eventos')
          .insert(evento.toJson())
          .select()
          .single();

      final created = EntregaEvento.fromJson(data);

      // Enviar notificação para eventos importantes
      await _sendEventNotification(created);

      return created;
    } catch (e) {
      debugPrint('Create evento error: $e');
      return null;
    }
  }

  /// Criar evento automaticamente baseado em localização (para geofencing)
  Future<void> createEventoAuto({
    required String entregaId,
    required TipoEventoEntrega tipo,
    required double latitude,
    required double longitude,
    String? observacao,
  }) async {
    await createEvento(
      entregaId: entregaId,
      tipo: tipo,
      observacao: observacao,
      latitude: latitude,
      longitude: longitude,
      metadata: {'automatico': true},
    );
  }

  /// Buscar eventos de um tipo específico
  Future<List<EntregaEvento>> getEventosByTipo(String entregaId, TipoEventoEntrega tipo) async {
    try {
      final data = await SupabaseConfig.client
          .from('entrega_eventos')
          .select()
          .eq('entrega_id', entregaId)
          .eq('tipo', tipo.value)
          .order('timestamp', ascending: false);
      return (data as List).map((json) => EntregaEvento.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get eventos by tipo error: $e');
      return [];
    }
  }

  /// Buscar último evento de uma entrega
  Future<EntregaEvento?> getUltimoEvento(String entregaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('entrega_eventos')
          .select()
          .eq('entrega_id', entregaId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return EntregaEvento.fromJson(data);
    } catch (e) {
      debugPrint('Get ultimo evento error: $e');
      return null;
    }
  }

  /// Criar eventos para mudança de status (migração do tracking_historico)
  Future<void> createEventoFromStatus(String entregaId, String status, {String? observacao}) async {
    TipoEventoEntrega? tipo;
    switch (status) {
      // Novo enum (atual)
      case 'aguardando':
        tipo = TipoEventoEntrega.aceite;
        break;
      case 'saiu_para_coleta':
        tipo = TipoEventoEntrega.inicioColeta;
        break;
      case 'saiu_para_entrega':
        tipo = TipoEventoEntrega.inicioRota;
        break;
      case 'entregue':
        tipo = TipoEventoEntrega.finalizado;
        break;
      case 'problema':
        tipo = TipoEventoEntrega.problema;
        break;
      case 'cancelada':
        tipo = TipoEventoEntrega.cancelado;
        break;

      // Compatibilidade (status antigos)
      case 'aguardando_coleta':
        tipo = TipoEventoEntrega.aceite;
        break;
      case 'em_coleta':
        tipo = TipoEventoEntrega.inicioColeta;
        break;
      case 'coletado':
        tipo = TipoEventoEntrega.carregou;
        break;
      case 'em_transito':
        tipo = TipoEventoEntrega.inicioRota;
        break;
      case 'em_entrega':
        tipo = TipoEventoEntrega.chegadaDestino;
        break;
      case 'devolvida':
        // Não existe um tipo específico hoje; tratamos como cancelamento (devolução).
        tipo = TipoEventoEntrega.cancelado;
        observacao = (observacao == null || observacao.isEmpty) ? 'Entrega devolvida' : observacao;
        break;
    }

    if (tipo != null) {
      await createEvento(entregaId: entregaId, tipo: tipo, observacao: observacao);
    }
  }

  Future<void> _sendEventNotification(EntregaEvento evento) async {
    try {
      // Notificar apenas eventos importantes
      final tiposImportantes = [
        TipoEventoEntrega.aceite,
        TipoEventoEntrega.chegadaColeta,
        TipoEventoEntrega.carregou,
        TipoEventoEntrega.inicioRota,
        TipoEventoEntrega.chegadaDestino,
        TipoEventoEntrega.finalizado,
        TipoEventoEntrega.problema,
        TipoEventoEntrega.desvioRota,
        TipoEventoEntrega.paradaProlongada,
      ];

      if (tiposImportantes.contains(evento.tipo)) {
        await NotificationService.instance.showTrackingNotification(
          title: 'Atualização de Entrega',
          message: evento.tipo.displayName,
          entregaId: evento.entregaId,
        );
      }
    } catch (e) {
      debugPrint('Send event notification error: $e');
    }
  }
}
