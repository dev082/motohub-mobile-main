/// Ponto de localização capturado
class LocationPoint {
  final String id;
  final String emailMotorista;
  final String? entregaId;
  final double latitude;
  final double longitude;
  final double? precisao;
  final double? velocidade;
  final double? heading;
  final DateTime timestamp;
  final String status;
  final bool synced;

  LocationPoint({
    required this.id,
    required this.emailMotorista,
    this.entregaId,
    required this.latitude,
    required this.longitude,
    this.precisao,
    this.velocidade,
    this.heading,
    required this.timestamp,
    required this.status,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email_motorista': emailMotorista,
        'entrega_id': entregaId,
        'latitude': latitude,
        'longitude': longitude,
        'precisao': precisao,
        'velocidade': velocidade,
        'bussola_pos': heading,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status,
        'synced': synced ? 1 : 0,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        id: json['id'] as String,
        emailMotorista: json['email_motorista'] as String,
        entregaId: json['entrega_id'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        precisao: json['precisao'] != null ? (json['precisao'] as num).toDouble() : null,
        velocidade: json['velocidade'] != null ? (json['velocidade'] as num).toDouble() : null,
        heading: json['bussola_pos'] != null ? (json['bussola_pos'] as num).toDouble() : null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        status: json['status'] as String,
        synced: (json['synced'] as int) == 1,
      );

  Map<String, dynamic> toSupabaseJson() => {
        'email_motorista': emailMotorista,
        'entrega_id': entregaId,
        'latitude': latitude,
        'longitude': longitude,
        'precisao': precisao,
        'velocidade': velocidade,
        'bussola_pos': heading,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status == 'online' || status == 'em_rota' || status == 'em_entrega',
        'visivel': true,
      };
}
