/// Estados de rastreamento do motorista
enum TrackingState {
  /// Motorista offline (rastreamento desativado)
  offline,

  /// Motorista online sem entrega ativa
  onlineSemEntrega,

  /// Motorista em rota para coleta
  emRotaColeta,

  /// Motorista em rota para entrega
  emEntrega,

  /// Entrega finalizada (transitório)
  finalizado;

  String get value {
    switch (this) {
      case TrackingState.offline:
        return 'offline';
      case TrackingState.onlineSemEntrega:
        return 'online_sem_entrega';
      case TrackingState.emRotaColeta:
        return 'em_rota_coleta';
      case TrackingState.emEntrega:
        return 'em_entrega';
      case TrackingState.finalizado:
        return 'finalizado';
    }
  }

  static TrackingState fromString(String value) {
    switch (value) {
      case 'offline':
        return TrackingState.offline;
      case 'online_sem_entrega':
        return TrackingState.onlineSemEntrega;
      case 'em_rota_coleta':
        return TrackingState.emRotaColeta;
      case 'em_entrega':
        return TrackingState.emEntrega;
      case 'finalizado':
        return TrackingState.finalizado;
      default:
        return TrackingState.offline;
    }
  }
}

/// Configuração de precisão e intervalo por estado
class TrackingConfig {
  final int intervalSeconds;
  final double distanceFilterMeters;
  final int accuracyMeters;

  const TrackingConfig({
    required this.intervalSeconds,
    required this.distanceFilterMeters,
    required this.accuracyMeters,
  });

  static TrackingConfig forState(TrackingState state) {
    switch (state) {
      case TrackingState.offline:
        return const TrackingConfig(intervalSeconds: 0, distanceFilterMeters: 0, accuracyMeters: 0);
      case TrackingState.onlineSemEntrega:
        return const TrackingConfig(intervalSeconds: 45, distanceFilterMeters: 50, accuracyMeters: 100);
      case TrackingState.emRotaColeta:
        return const TrackingConfig(intervalSeconds: 10, distanceFilterMeters: 20, accuracyMeters: 50);
      case TrackingState.emEntrega:
        return const TrackingConfig(intervalSeconds: 5, distanceFilterMeters: 10, accuracyMeters: 20);
      case TrackingState.finalizado:
        return const TrackingConfig(intervalSeconds: 60, distanceFilterMeters: 100, accuracyMeters: 200);
    }
  }
}
