import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hubfrete/services/location_database_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Sync Engine: envia pontos da fila local para o Supabase em lotes
class LocationSyncService {
  static final LocationSyncService instance = LocationSyncService._();
  LocationSyncService._();

  Timer? _syncTimer;
  bool _isSyncing = false;

  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const int _batchSize = 20;

  /// Inicia sincronização periódica (a cada 15s)
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => syncPendingPoints(),
    );
    debugPrint('[LocationSync] Sincronização periódica iniciada');
  }

  /// Para sincronização periódica
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _retryCount = 0;
    debugPrint('[LocationSync] Sincronização periódica parada');
  }

  /// Sincroniza pontos pendentes com o Supabase
  Future<void> syncPendingPoints() async {
    if (_isSyncing) {
      debugPrint('[LocationSync] Sync já em andamento, ignorando');
      return;
    }

    _isSyncing = true;

    try {
      final points = await LocationDatabaseService.instance
          .getUnsyncedPoints(limit: _batchSize);

      if (points.isEmpty) {
        _retryCount = 0;
        return;
      }

      debugPrint('[LocationSync] Sincronizando ${points.length} pontos...');

      /// Mantém apenas o ponto mais recente por motorista
      final Map<String, Map<String, dynamic>> byMotorista = {};

      for (final point in points) {
        final existing = byMotorista[point.motoristaId];

        if (existing == null) {
          final json = point.toSupabaseJson();
          json['_ts'] = point.timestamp.millisecondsSinceEpoch;
          byMotorista[point.motoristaId] = json;
          continue;
        }

        final existingTs = (existing['_ts'] as num).toInt();
        final currentTs = point.timestamp.millisecondsSinceEpoch;

        if (currentTs > existingTs) {
          final json = point.toSupabaseJson();
          json['_ts'] = currentTs;
          byMotorista[point.motoristaId] = json;
        }
      }

      /// Remove helper antes de enviar
      final payload = byMotorista.values.map((e) {
        e.remove('_ts');
        return e;
      }).toList();

      /// UPSERT em batch
      await SupabaseConfig.client
          .from('localizacoes')
          .upsert(payload, onConflict: 'motorista_id');

      /// Marca como sincronizados
      await LocationDatabaseService.instance.markAsSynced(
        points.map((p) => p.id).toList(),
      );

      _retryCount = 0;

      debugPrint(
        '[LocationSync] ${payload.length} motoristas sincronizados com sucesso',
      );

      /// Limpa pontos antigos já sincronizados
      await LocationDatabaseService.instance.cleanOldSyncedPoints();
    } catch (e) {
      _retryCount++;
      debugPrint(
        '[LocationSync] Erro na sincronização '
        '(tentativa $_retryCount/$_maxRetries): $e',
      );

      if (_retryCount >= _maxRetries) {
        debugPrint(
          '[LocationSync] Limite de tentativas atingido, aguardando próximo ciclo',
        );
        _retryCount = 0;
      }

      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Força sincronização imediata
  Future<void> forceSyncNow() async {
    debugPrint('[LocationSync] Sincronização forçada');
    await syncPendingPoints();
  }
}