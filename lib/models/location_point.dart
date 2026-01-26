/// Location point model for real-time tracking
class LocationPoint {
  final String id;
  final String entregaId;
  final String motoristaId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final int? batteryLevel;
  final bool isMoving;
  final DateTime createdAt;

  LocationPoint({
    required this.id,
    required this.entregaId,
    required this.motoristaId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
    this.isMoving = true,
    required this.createdAt,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        id: json['id'] as String,
        entregaId: json['entrega_id'] as String,
        motoristaId: json['motorista_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
        speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
        heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
        altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
        batteryLevel: json['battery_level'] as int?,
        isMoving: json['is_moving'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entrega_id': entregaId,
        'motorista_id': motoristaId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'altitude': altitude,
        'battery_level': batteryLevel,
        'is_moving': isMoving,
        'created_at': createdAt.toIso8601String(),
      };

  LocationPoint copyWith({
    String? id,
    String? entregaId,
    String? motoristaId,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
    int? batteryLevel,
    bool? isMoving,
    DateTime? createdAt,
  }) =>
      LocationPoint(
        id: id ?? this.id,
        entregaId: entregaId ?? this.entregaId,
        motoristaId: motoristaId ?? this.motoristaId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        accuracy: accuracy ?? this.accuracy,
        speed: speed ?? this.speed,
        heading: heading ?? this.heading,
        altitude: altitude ?? this.altitude,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        isMoving: isMoving ?? this.isMoving,
        createdAt: createdAt ?? this.createdAt,
      );
}
