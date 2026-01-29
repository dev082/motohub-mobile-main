/// Ponto de localização capturado (GPS real-time)
class LocationPoint {
  final String id;
  final String motoristaId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? precisao;
  final double? velocidade;
  final double? heading;
  final DateTime timestamp;
  final bool synced;

  LocationPoint({
    required this.id,
    required this.motoristaId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.precisao,
    this.velocidade,
    this.heading,
    required this.timestamp,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'motorista_id': motoristaId,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'precisao': precisao,
        'velocidade': velocidade,
        'bussola_pos': heading,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'synced': synced ? 1 : 0,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        id: json['id'] as String,
        motoristaId: json['motorista_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
        precisao: json['precisao'] != null ? (json['precisao'] as num).toDouble() : null,
        velocidade: json['velocidade'] != null ? (json['velocidade'] as num).toDouble() : null,
        heading: json['bussola_pos'] != null ? (json['bussola_pos'] as num).toDouble() : null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        synced: (json['synced'] as int) == 1,
      );

  /// Converte para JSON do Supabase (tabela 'localizações')
  /// Apenas campos GPS + motorista_id - trigger faz o resto!
  Map<String, dynamic> toSupabaseJson() => {
        'motorista_id': motoristaId,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'precisao': precisao,
        'velocidade': velocidade,
        'bussola_pos': heading,
      };
}
