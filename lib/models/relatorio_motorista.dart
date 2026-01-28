import 'package:hubfrete/models/entrega.dart';

/// Aggregated report data for a motorista.
class RelatorioMotorista {
  final int totalEntregas;
  final int entregues;
  final int canceladas;
  final int emAndamento;
  final double kmEstimados;
  final Map<StatusEntrega, int> contagemPorStatus;
  final List<RelatorioDia> ultimos7Dias;

  const RelatorioMotorista({
    required this.totalEntregas,
    required this.entregues,
    required this.canceladas,
    required this.emAndamento,
    required this.kmEstimados,
    required this.contagemPorStatus,
    required this.ultimos7Dias,
  });
}

/// Daily aggregation used in charts.
class RelatorioDia {
  final DateTime date;
  final int entregues;
  final int canceladas;

  const RelatorioDia({
    required this.date,
    required this.entregues,
    required this.canceladas,
  });
}
