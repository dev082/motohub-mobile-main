import 'package:flutter/foundation.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/models/motorista_kpi.dart';
import 'package:motohub/supabase/supabase_config.dart';

/// Service para gerenciar KPIs de motoristas
class MotoristaKPIService {
  /// Buscar KPIs de um motorista em um período
  Future<List<MotoristaKPI>> getByMotoristaId(String motoristaId, {DateTime? inicio, DateTime? fim}) async {
    try {
      var query = SupabaseConfig.client
          .from('motorista_kpis')
          .select()
          .eq('motorista_id', motoristaId);

      if (inicio != null) {
        query = query.gte('periodo_inicio', inicio.toIso8601String());
      }
      if (fim != null) {
        query = query.lte('periodo_fim', fim.toIso8601String());
      }

      final data = await query.order('periodo_inicio', ascending: false);
      return (data as List).map((json) => MotoristaKPI.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get KPIs error: $e');
      return [];
    }
  }

  /// Criar/atualizar KPI do motorista
  Future<MotoristaKPI?> upsert({
    required String motoristaId,
    required DateTime periodoInicio,
    required DateTime periodoFim,
    double kmRodado = 0.0,
    Duration tempoEmRota = Duration.zero,
    Duration tempoParado = Duration.zero,
    double consumoEstimadoLitros = 0.0,
    double custoEstimado = 0.0,
    int entregasFinalizadas = 0,
    int entregasAtrasadas = 0,
    double mediaPedagios = 0.0,
  }) async {
    try {
      final taxaAtraso = entregasFinalizadas > 0 ? (entregasAtrasadas / entregasFinalizadas) * 100 : 0.0;
      final now = DateTime.now();

      final kpi = MotoristaKPI(
        id: '',
        motoristaId: motoristaId,
        periodoInicio: periodoInicio,
        periodoFim: periodoFim,
        kmRodado: kmRodado,
        tempoEmRota: tempoEmRota,
        tempoParado: tempoParado,
        consumoEstimadoLitros: consumoEstimadoLitros,
        custoEstimado: custoEstimado,
        entregasFinalizadas: entregasFinalizadas,
        entregasAtrasadas: entregasAtrasadas,
        taxaAtraso: taxaAtraso,
        mediaPedagios: mediaPedagios,
        createdAt: now,
        updatedAt: now,
      );

      final data = await SupabaseConfig.client
          .from('motorista_kpis')
          .upsert(kpi.toJson())
          .select()
          .single();

      return MotoristaKPI.fromJson(data);
    } catch (e) {
      debugPrint('Upsert KPI error: $e');
      return null;
    }
  }

  /// Calcular KPIs do período atual (mês corrente)
  Future<MotoristaKPI?> calcularKPIAtual(String motoristaId) async {
    try {
      final now = DateTime.now();
      final inicio = DateTime(now.year, now.month, 1);
      final fim = DateTime(now.year, now.month + 1, 0);

      // Buscar entregas do período
      final entregas = await SupabaseConfig.client
          .from('entregas')
          .select('*, tracking_historico(*)')
          .eq('motorista_id', motoristaId)
          .gte('created_at', inicio.toIso8601String())
          .lte('created_at', fim.toIso8601String());

      // Calcular métricas
      int finalizadas = 0;
      int atrasadas = 0;
      double kmTotal = 0.0;
      int minutosRota = 0;
      int minutosParado = 0;

      for (final e in entregas as List) {
        if (e['status'] == StatusEntrega.entregue.value) {
          finalizadas++;
          // Verificar se atrasou (placeholder - implementar lógica real)
          // atrasadas += ...
        }
        // Calcular km e tempo (placeholder - implementar cálculo real baseado no tracking)
      }

      return await upsert(
        motoristaId: motoristaId,
        periodoInicio: inicio,
        periodoFim: fim,
        kmRodado: kmTotal,
        tempoEmRota: Duration(minutes: minutosRota),
        tempoParado: Duration(minutes: minutosParado),
        entregasFinalizadas: finalizadas,
        entregasAtrasadas: atrasadas,
      );
    } catch (e) {
      debugPrint('Calcular KPI atual error: $e');
      return null;
    }
  }

  /// Buscar/criar configuração de custos de um veículo
  Future<VeiculoCustoConfig?> getVeiculoCustoConfig(String veiculoId) async {
    try {
      final data = await SupabaseConfig.client
          .from('veiculo_custo_config')
          .select()
          .eq('veiculo_id', veiculoId)
          .maybeSingle();

      if (data == null) {
        // Criar config padrão
        return await _createDefaultConfig(veiculoId);
      }
      return VeiculoCustoConfig.fromJson(data);
    } catch (e) {
      debugPrint('Get veiculo custo config error: $e');
      return null;
    }
  }

  /// Atualizar configuração de custos
  Future<bool> updateVeiculoCustoConfig(String veiculoId, {
    double? consumoUrbanoKmL,
    double? consumoRodoviarioKmL,
    double? custoPorKm,
    double? pedagioMedio,
  }) async {
    try {
      final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
      if (consumoUrbanoKmL != null) updates['consumo_urbano_km_l'] = consumoUrbanoKmL;
      if (consumoRodoviarioKmL != null) updates['consumo_rodoviario_km_l'] = consumoRodoviarioKmL;
      if (custoPorKm != null) updates['custo_por_km'] = custoPorKm;
      if (pedagioMedio != null) updates['pedagio_medio'] = pedagioMedio;

      await SupabaseConfig.client
          .from('veiculo_custo_config')
          .update(updates)
          .eq('veiculo_id', veiculoId);
      return true;
    } catch (e) {
      debugPrint('Update veiculo custo config error: $e');
      return false;
    }
  }

  Future<VeiculoCustoConfig?> _createDefaultConfig(String veiculoId) async {
    try {
      final config = VeiculoCustoConfig(
        veiculoId: veiculoId,
        updatedAt: DateTime.now(),
      );
      final data = await SupabaseConfig.client
          .from('veiculo_custo_config')
          .insert(config.toJson())
          .select()
          .single();
      return VeiculoCustoConfig.fromJson(data);
    } catch (e) {
      debugPrint('Create default config error: $e');
      return null;
    }
  }

  /// Estimar consumo e custo de uma rota
  Map<String, double> estimarCustoRota(double kmTotal, VeiculoCustoConfig config, {double ratioUrbano = 0.3}) {
    final kmUrbano = kmTotal * ratioUrbano;
    final kmRodoviario = kmTotal * (1 - ratioUrbano);

    final litrosUrbano = kmUrbano / config.consumoUrbanoKmL;
    final litrosRodoviario = kmRodoviario / config.consumoRodoviarioKmL;
    final litrosTotal = litrosUrbano + litrosRodoviario;

    final custoTotal = (kmTotal * config.custoPorKm) + config.pedagioMedio;

    return {
      'km_total': kmTotal,
      'litros_total': litrosTotal,
      'custo_total': custoTotal,
      'custo_por_km': config.custoPorKm,
      'pedagio': config.pedagioMedio,
    };
  }
}
