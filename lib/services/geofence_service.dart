import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/geofence.dart';
import 'package:hubfrete/models/entrega_evento.dart';
import 'package:hubfrete/services/entrega_evento_service.dart';
import 'package:hubfrete/services/notification_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Service para gerenciar geofences
class GeofenceService {
  final _eventoService = EntregaEventoService();
  final _entregaService = EntregaService();

  /// Buscar geofences de uma entrega
  Future<List<Geofence>> getByEntregaId(String entregaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('geofences')
          .select()
          .eq('entrega_id', entregaId)
          .eq('ativo', true)
          .order('created_at', ascending: false);
      return (data as List).map((json) => Geofence.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get geofences error: $e');
      return [];
    }
  }

  /// Criar nova geofence
  Future<Geofence?> create({
    String? entregaId,
    required String nome,
    required double latitude,
    required double longitude,
    double raioMetros = 200.0,
    required TipoGeofence tipo,
    bool notificarEntrada = true,
    bool notificarSaida = false,
    bool mudarStatusAuto = false,
    String? statusAposEntrada,
    String? statusAposSaida,
  }) async {
    try {
      final now = DateTime.now();
      final geofence = Geofence(
        id: '',
        entregaId: entregaId,
        nome: nome,
        latitude: latitude,
        longitude: longitude,
        raioMetros: raioMetros,
        tipo: tipo,
        ativo: true,
        notificarEntrada: notificarEntrada,
        notificarSaida: notificarSaida,
        mudarStatusAuto: mudarStatusAuto,
        statusAposEntrada: statusAposEntrada,
        statusAposSaida: statusAposSaida,
        createdAt: now,
        updatedAt: now,
      );

      final data = await SupabaseConfig.client
          .from('geofences')
          .insert(geofence.toJson())
          .select()
          .single();

      return Geofence.fromJson(data);
    } catch (e) {
      debugPrint('Create geofence error: $e');
      return null;
    }
  }

  /// Atualizar geofence
  Future<bool> update(String geofenceId, {
    String? nome,
    double? latitude,
    double? longitude,
    double? raioMetros,
    bool? ativo,
    bool? notificarEntrada,
    bool? notificarSaida,
    bool? mudarStatusAuto,
    String? statusAposEntrada,
    String? statusAposSaida,
  }) async {
    try {
      final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
      if (nome != null) updates['nome'] = nome;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (raioMetros != null) updates['raio_metros'] = raioMetros;
      if (ativo != null) updates['ativo'] = ativo;
      if (notificarEntrada != null) updates['notificar_entrada'] = notificarEntrada;
      if (notificarSaida != null) updates['notificar_saida'] = notificarSaida;
      if (mudarStatusAuto != null) updates['mudar_status_auto'] = mudarStatusAuto;
      if (statusAposEntrada != null) updates['status_apos_entrada'] = statusAposEntrada;
      if (statusAposSaida != null) updates['status_apos_saida'] = statusAposSaida;

      await SupabaseConfig.client.from('geofences').update(updates).eq('id', geofenceId);
      return true;
    } catch (e) {
      debugPrint('Update geofence error: $e');
      return false;
    }
  }

  /// Deletar geofence
  Future<bool> delete(String geofenceId) async {
    try {
      await SupabaseConfig.client.from('geofences').delete().eq('id', geofenceId);
      return true;
    } catch (e) {
      debugPrint('Delete geofence error: $e');
      return false;
    }
  }

  /// Verificar se posição está dentro da geofence
  bool isDentroGeofence(Geofence geofence, double lat, double lon) {
    final distanciaMetros = _calcularDistancia(geofence.latitude, geofence.longitude, lat, lon);
    return distanciaMetros <= geofence.raioMetros;
  }

  /// Checar todas as geofences de uma entrega e disparar eventos se necessário
  Future<void> checkGeofences(String entregaId, double currentLat, double currentLon, Map<String, bool> estadoAnterior) async {
    try {
      final geofences = await getByEntregaId(entregaId);
      for (final geofence in geofences) {
        final dentroAgora = isDentroGeofence(geofence, currentLat, currentLon);
        final dentroAntes = estadoAnterior[geofence.id] ?? false;

        // Entrou na geofence
        if (dentroAgora && !dentroAntes) {
          await _handleEntrada(geofence, entregaId, currentLat, currentLon);
        }

        // Saiu da geofence
        if (!dentroAgora && dentroAntes) {
          await _handleSaida(geofence, entregaId, currentLat, currentLon);
        }

        // Atualizar estado
        estadoAnterior[geofence.id] = dentroAgora;
      }
    } catch (e) {
      debugPrint('Check geofences error: $e');
    }
  }

  Future<void> _handleEntrada(Geofence geofence, String entregaId, double lat, double lon) async {
    // Criar evento
    await _eventoService.createEventoAuto(
      entregaId: entregaId,
      tipo: TipoEventoEntrega.entradaGeofence,
      latitude: lat,
      longitude: lon,
      observacao: 'Entrou em ${geofence.nome}',
    );

    // Notificar
    if (geofence.notificarEntrada) {
      await NotificationService.instance.showTrackingNotification(
        title: 'Entrada em Área',
        message: 'Motorista entrou em ${geofence.nome}',
        entregaId: entregaId,
      );
    }

    // Mudar status automaticamente
    if (geofence.mudarStatusAuto && geofence.statusAposEntrada != null) {
      final statusEnum = _parseStatus(geofence.statusAposEntrada!);
      if (statusEnum != null) {
        await _entregaService.updateStatus(entregaId, statusEnum);
      }
    }
  }

  Future<void> _handleSaida(Geofence geofence, String entregaId, double lat, double lon) async {
    // Criar evento
    await _eventoService.createEventoAuto(
      entregaId: entregaId,
      tipo: TipoEventoEntrega.saidaGeofence,
      latitude: lat,
      longitude: lon,
      observacao: 'Saiu de ${geofence.nome}',
    );

    // Notificar
    if (geofence.notificarSaida) {
      await NotificationService.instance.showTrackingNotification(
        title: 'Saída de Área',
        message: 'Motorista saiu de ${geofence.nome}',
        entregaId: entregaId,
      );
    }

    // Mudar status automaticamente
    if (geofence.mudarStatusAuto && geofence.statusAposSaida != null) {
      final statusEnum = _parseStatus(geofence.statusAposSaida!);
      if (statusEnum != null) {
        await _entregaService.updateStatus(entregaId, statusEnum);
      }
    }
  }

  /// Calcular distância entre dois pontos (em metros) usando fórmula de Haversine
  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Raio da Terra em metros
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;

  dynamic _parseStatus(String status) {
    // Função auxiliar para converter string para StatusEntrega
    // Retorna null se não conseguir fazer parse
    return null; // Placeholder - implementar conforme necessário
  }
}
