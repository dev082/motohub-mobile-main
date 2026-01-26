/// Geofence - cerca virtual para monitoramento de entregas
class Geofence {
  final String id;
  final String? entregaId;
  final String nome;
  final double latitude;
  final double longitude;
  final double raioMetros;
  final TipoGeofence tipo;
  final bool ativo;
  final bool notificarEntrada;
  final bool notificarSaida;
  final bool mudarStatusAuto;
  final String? statusAposEntrada;
  final String? statusAposSaida;
  final DateTime createdAt;
  final DateTime updatedAt;

  Geofence({
    required this.id,
    this.entregaId,
    required this.nome,
    required this.latitude,
    required this.longitude,
    this.raioMetros = 200.0,
    required this.tipo,
    this.ativo = true,
    this.notificarEntrada = true,
    this.notificarSaida = false,
    this.mudarStatusAuto = false,
    this.statusAposEntrada,
    this.statusAposSaida,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) => Geofence(
        id: json['id'] as String,
        entregaId: json['entrega_id'] as String?,
        nome: json['nome'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        raioMetros: json['raio_metros'] != null ? (json['raio_metros'] as num).toDouble() : 200.0,
        tipo: TipoGeofence.fromString(json['tipo'] as String),
        ativo: json['ativo'] as bool? ?? true,
        notificarEntrada: json['notificar_entrada'] as bool? ?? true,
        notificarSaida: json['notificar_saida'] as bool? ?? false,
        mudarStatusAuto: json['mudar_status_auto'] as bool? ?? false,
        statusAposEntrada: json['status_apos_entrada'] as String?,
        statusAposSaida: json['status_apos_saida'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entrega_id': entregaId,
        'nome': nome,
        'latitude': latitude,
        'longitude': longitude,
        'raio_metros': raioMetros,
        'tipo': tipo.value,
        'ativo': ativo,
        'notificar_entrada': notificarEntrada,
        'notificar_saida': notificarSaida,
        'mudar_status_auto': mudarStatusAuto,
        'status_apos_entrada': statusAposEntrada,
        'status_apos_saida': statusAposSaida,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Geofence copyWith({
    String? id,
    String? entregaId,
    String? nome,
    double? latitude,
    double? longitude,
    double? raioMetros,
    TipoGeofence? tipo,
    bool? ativo,
    bool? notificarEntrada,
    bool? notificarSaida,
    bool? mudarStatusAuto,
    String? statusAposEntrada,
    String? statusAposSaida,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Geofence(
        id: id ?? this.id,
        entregaId: entregaId ?? this.entregaId,
        nome: nome ?? this.nome,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        raioMetros: raioMetros ?? this.raioMetros,
        tipo: tipo ?? this.tipo,
        ativo: ativo ?? this.ativo,
        notificarEntrada: notificarEntrada ?? this.notificarEntrada,
        notificarSaida: notificarSaida ?? this.notificarSaida,
        mudarStatusAuto: mudarStatusAuto ?? this.mudarStatusAuto,
        statusAposEntrada: statusAposEntrada ?? this.statusAposEntrada,
        statusAposSaida: statusAposSaida ?? this.statusAposSaida,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

enum TipoGeofence {
  origem,
  destino,
  parada,
  personalizado;

  String get value => name;

  String get displayName {
    switch (this) {
      case TipoGeofence.origem:
        return 'Origem';
      case TipoGeofence.destino:
        return 'Destino';
      case TipoGeofence.parada:
        return 'Parada';
      case TipoGeofence.personalizado:
        return 'Personalizado';
    }
  }

  static TipoGeofence fromString(String value) {
    switch (value) {
      case 'origem':
        return TipoGeofence.origem;
      case 'destino':
        return TipoGeofence.destino;
      case 'parada':
        return TipoGeofence.parada;
      case 'personalizado':
        return TipoGeofence.personalizado;
      default:
        return TipoGeofence.personalizado;
    }
  }
}
