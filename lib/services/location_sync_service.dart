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
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) => syncPendingPoints());
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
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final points = await LocationDatabaseService.instance.getUnsyncedPoints(limit: _batchSize);
      if (points.isEmpty) {
        _retryCount = 0;
        return;
      }

      debugPrint('[LocationSync] Sincronizando ${points.length} pontos...');

      // Agrupa por email_motorista para fazer UPSERT
      final Map<String, Map<String, dynamic>> byEmail = {};
      for (final point in points) {
        // Sempre enviar o ponto mais recente por email
        final existing = byEmail[point.emailMotorista];
        if (existing == null || (point.timestamp.millisecondsSinceEpoch > (existing['timestamp'] as int))) {
          byEmail[point.emailMotorista] = point.toSupabaseJson();
        }
      }

      // UPSERT na tabela localizações (posição atual)
      for (final data in byEmail.values) {
        try {
          await SupabaseConfig.client.from('localizações').upsert(data, onConflict: 'email_motorista');
        } catch (e) {
          debugPrint('[LocationSync] Erro ao fazer UPSERT: $e');
          throw e;
        }
      }

      // Marca como sincronizados
      await LocationDatabaseService.instance.markAsSynced(points.map((p) => p.id).toList());
      _retryCount = 0;
      debugPrint('[LocationSync] ${points.length} pontos sincronizados com sucesso');

      // Limpa pontos antigos sincronizados
      await LocationDatabaseService.instance.cleanOldSyncedPoints();
    } catch (e) {
      _retryCount++;
      debugPrint('[LocationSync] Erro na sincronização (tentativa $_retryCount/$_maxRetries): $e');

      // Backoff exponencial
      if (_retryCount >= _maxRetries) {
        debugPrint('[LocationSync] Limite de tentativas atingido, aguardando próximo ciclo');
        _retryCount = 0;
      }
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
