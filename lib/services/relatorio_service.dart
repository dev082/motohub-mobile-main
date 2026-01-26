import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/models/relatorio_motorista.dart';
import 'package:motohub/services/location_service.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/supabase/supabase_config.dart';

/// Builds aggregated metrics for the Relatórios screen.
///
/// Notes on KM calculation:
/// - We estimate the distance from the `tracking_historico` lat/lon points.
/// - This is best-effort and depends on tracking data existing.
class RelatorioService {
  final EntregaService _entregaService;
  final LocationService _locationService;

  RelatorioService({EntregaService? entregaService, LocationService? locationService})
      : _entregaService = entregaService ?? EntregaService(),
        _locationService = locationService ?? LocationService();

  Future<RelatorioMotorista> buildMotoristaReport(
    String motoristaId, {
    Duration window = const Duration(days: 30),
  }) async {
    final now = DateTime.now();
    final from = now.subtract(window);

    try {
      final entregas = await _entregaService.getMotoristaEntregas(motoristaId);

      final contagem = <StatusEntrega, int>{};
      for (final s in StatusEntrega.values) {
        contagem[s] = 0;
      }
      for (final e in entregas) {
        contagem[e.status] = (contagem[e.status] ?? 0) + 1;
      }

      final delivered = contagem[StatusEntrega.entregue] ?? 0;
      final cancelled = contagem[StatusEntrega.cancelada] ?? 0;
      final inProgress = entregas.where((e) => _isActiveStatus(e.status)).length;

      final km = await _estimateKmFromTracking(
        motoristaId: motoristaId,
        entregas: entregas,
        from: from,
      );

      final last7 = _buildLast7Days(entregas: entregas, now: now);

      return RelatorioMotorista(
        totalEntregas: entregas.length,
        entregues: delivered,
        canceladas: cancelled,
        emAndamento: inProgress,
        kmEstimados: km,
        contagemPorStatus: contagem,
        ultimos7Dias: last7,
      );
    } catch (e) {
      debugPrint('RelatorioService.buildMotoristaReport error: $e');
      rethrow;
    }
  }

  bool _isActiveStatus(StatusEntrega s) {
    switch (s) {
      case StatusEntrega.aguardando:
      case StatusEntrega.saiuParaColeta:
      case StatusEntrega.saiuParaEntrega:
        return true;
      case StatusEntrega.entregue:
      case StatusEntrega.problema:
      case StatusEntrega.cancelada:
        return false;
    }
  }

  List<RelatorioDia> _buildLast7Days({required List<Entrega> entregas, required DateTime now}) {
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final days = List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return RelatorioDia(date: d, entregues: 0, canceladas: 0);
    });

    final indexByKey = <String, int>{
      for (var i = 0; i < days.length; i++) _dayKey(days[i].date): i,
    };

    for (final e in entregas) {
      // Prefer delivery completion time; fallback to updatedAt.
      final ts = e.entregueEm ?? e.updatedAt;
      if (ts.isBefore(start)) continue;

      final idx = indexByKey[_dayKey(ts)];
      if (idx == null) continue;

      final current = days[idx];
      if (e.status == StatusEntrega.entregue) {
        days[idx] = RelatorioDia(date: current.date, entregues: current.entregues + 1, canceladas: current.canceladas);
      } else if (e.status == StatusEntrega.cancelada) {
        days[idx] = RelatorioDia(date: current.date, entregues: current.entregues, canceladas: current.canceladas + 1);
      }
    }
    return days;
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<double> _estimateKmFromTracking({
    required String motoristaId,
    required List<Entrega> entregas,
    required DateTime from,
  }) async {
    // Only for recent/updated deliveries to reduce load.
    final List<Entrega> candidates = entregas.where((e) => e.updatedAt.isAfter(from)).take(20).toList(growable: false);
    if (candidates.isEmpty) return 0;

    double totalMeters = 0;
    for (final e in candidates) {
      try {
        final points = await SupabaseConfig.client
            .from('tracking_historico')
            .select('latitude, longitude, created_at')
            .eq('entrega_id', e.id)
            .gte('created_at', from.toIso8601String())
            .order('created_at', ascending: true)
            .limit(400);

        final list = (points as List)
            .map((row) => (row as Map<String, dynamic>))
            .map((row) {
              final lat = row['latitude'];
              final lon = row['longitude'];
              if (lat == null || lon == null) return null;
              return (lat as num).toDouble().isFinite && (lon as num).toDouble().isFinite
                  ? _LatLng((lat as num).toDouble(), (lon as num).toDouble())
                  : null;
            })
            .whereType<_LatLng>()
            .toList();

        for (var i = 1; i < list.length; i++) {
          totalMeters += _locationService.calculateDistance(list[i - 1].lat, list[i - 1].lon, list[i].lat, list[i].lon);
        }
      } catch (err) {
        debugPrint('RelatorioService estimate km for entrega=${e.id} error: $err');
      }
    }

    // Clamp silly values (defensive): if tracking is noisy.
    final km = totalMeters / 1000.0;
    return max(0, min(km, 999999));
  }
}

class _LatLng {
  final double lat;
  final double lon;
  const _LatLng(this.lat, this.lon);
}
