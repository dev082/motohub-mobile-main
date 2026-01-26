/// Tracking session model for delivery tracking
class TrackingSession {
  final String id;
  final String entregaId;
  final String motoristaId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TrackingStatus status;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final double? averageSpeedKmh;
  final double? maxSpeedKmh;
  final int pointsCollected;
  final DateTime? lastLocationAt;
  final Map<String, dynamic> metadata;

  TrackingSession({
    required this.id,
    required this.entregaId,
    required this.motoristaId,
    required this.startedAt,
    this.endedAt,
    this.status = TrackingStatus.active,
    this.totalDistanceKm = 0,
    this.totalDurationSeconds = 0,
    this.averageSpeedKmh,
    this.maxSpeedKmh,
    this.pointsCollected = 0,
    this.lastLocationAt,
    this.metadata = const {},
  });

  factory TrackingSession.fromJson(Map<String, dynamic> json) => TrackingSession(
        id: json['id'] as String,
        entregaId: json['entrega_id'] as String,
        motoristaId: json['motorista_id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
        status: TrackingStatus.fromString(json['status'] as String? ?? 'active'),
        totalDistanceKm: json['total_distance_km'] != null ? (json['total_distance_km'] as num).toDouble() : 0,
        totalDurationSeconds: json['total_duration_seconds'] as int? ?? 0,
        averageSpeedKmh: json['average_speed_kmh'] != null ? (json['average_speed_kmh'] as num).toDouble() : null,
        maxSpeedKmh: json['max_speed_kmh'] != null ? (json['max_speed_kmh'] as num).toDouble() : null,
        pointsCollected: json['points_collected'] as int? ?? 0,
        lastLocationAt: json['last_location_at'] != null ? DateTime.parse(json['last_location_at'] as String) : null,
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entrega_id': entregaId,
        'motorista_id': motoristaId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'status': status.value,
        'total_distance_km': totalDistanceKm,
        'total_duration_seconds': totalDurationSeconds,
        'average_speed_kmh': averageSpeedKmh,
        'max_speed_kmh': maxSpeedKmh,
        'points_collected': pointsCollected,
        'last_location_at': lastLocationAt?.toIso8601String(),
        'metadata': metadata,
      };

  TrackingSession copyWith({
    String? id,
    String? entregaId,
    String? motoristaId,
    DateTime? startedAt,
    DateTime? endedAt,
    TrackingStatus? status,
    double? totalDistanceKm,
    int? totalDurationSeconds,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    int? pointsCollected,
    DateTime? lastLocationAt,
    Map<String, dynamic>? metadata,
  }) =>
      TrackingSession(
        id: id ?? this.id,
        entregaId: entregaId ?? this.entregaId,
        motoristaId: motoristaId ?? this.motoristaId,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        status: status ?? this.status,
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
        averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
        maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
        pointsCollected: pointsCollected ?? this.pointsCollected,
        lastLocationAt: lastLocationAt ?? this.lastLocationAt,
        metadata: metadata ?? this.metadata,
      );
}

enum TrackingStatus {
  active,
  paused,
  completed,
  cancelled;

  String get value => name;

  static TrackingStatus fromString(String value) {
    switch (value) {
      case 'active':
        return TrackingStatus.active;
      case 'paused':
        return TrackingStatus.paused;
      case 'completed':
        return TrackingStatus.completed;
      case 'cancelled':
        return TrackingStatus.cancelled;
      default:
        return TrackingStatus.active;
    }
  }

  String get displayName {
    switch (this) {
      case TrackingStatus.active:
        return 'Ativo';
      case TrackingStatus.paused:
        return 'Pausado';
      case TrackingStatus.completed:
        return 'Concluído';
      case TrackingStatus.cancelled:
        return 'Cancelado';
    }
  }
}
