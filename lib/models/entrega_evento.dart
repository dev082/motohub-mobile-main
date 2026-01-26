/// Modelo de evento de timeline da entrega (POD/Auditoria)
class EntregaEvento {
  final String id;
  final String entregaId;
  final TipoEventoEntrega tipo;
  final DateTime timestamp;
  final String? observacao;
  final double? latitude;
  final double? longitude;
  final String? userId;
  final String? userNome;
  final String? fotoUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  EntregaEvento({
    required this.id,
    required this.entregaId,
    required this.tipo,
    required this.timestamp,
    this.observacao,
    this.latitude,
    this.longitude,
    this.userId,
    this.userNome,
    this.fotoUrl,
    this.metadata,
    required this.createdAt,
  });

  factory EntregaEvento.fromJson(Map<String, dynamic> json) => EntregaEvento(
        id: json['id'] as String,
        entregaId: json['entrega_id'] as String,
        tipo: TipoEventoEntrega.fromString(json['tipo'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        observacao: json['observacao'] as String?,
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
        userId: json['user_id'] as String?,
        userNome: json['user_nome'] as String?,
        fotoUrl: json['foto_url'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entrega_id': entregaId,
        'tipo': tipo.value,
        'timestamp': timestamp.toIso8601String(),
        'observacao': observacao,
        'latitude': latitude,
        'longitude': longitude,
        'user_id': userId,
        'user_nome': userNome,
        'foto_url': fotoUrl,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };

  EntregaEvento copyWith({
    String? id,
    String? entregaId,
    TipoEventoEntrega? tipo,
    DateTime? timestamp,
    String? observacao,
    double? latitude,
    double? longitude,
    String? userId,
    String? userNome,
    String? fotoUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) =>
      EntregaEvento(
        id: id ?? this.id,
        entregaId: entregaId ?? this.entregaId,
        tipo: tipo ?? this.tipo,
        timestamp: timestamp ?? this.timestamp,
        observacao: observacao ?? this.observacao,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        userId: userId ?? this.userId,
        userNome: userNome ?? this.userNome,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        metadata: metadata ?? this.metadata,
        createdAt: createdAt ?? this.createdAt,
      );
}

enum TipoEventoEntrega {
  aceite,
  inicioColeta,
  chegadaColeta,
  carregou,
  inicioRota,
  parada,
  chegadaDestino,
  descarregou,
  finalizado,
  problema,
  cancelado,
  desvioRota,
  paradaProlongada,
  velocidadeAnormal,
  perdaSinal,
  recuperacaoSinal,
  entradaGeofence,
  saidaGeofence;

  String get value {
    switch (this) {
      case TipoEventoEntrega.inicioColeta:
        return 'inicio_coleta';
      case TipoEventoEntrega.chegadaColeta:
        return 'chegada_coleta';
      case TipoEventoEntrega.inicioRota:
        return 'inicio_rota';
      case TipoEventoEntrega.chegadaDestino:
        return 'chegada_destino';
      case TipoEventoEntrega.desvioRota:
        return 'desvio_rota';
      case TipoEventoEntrega.paradaProlongada:
        return 'parada_prolongada';
      case TipoEventoEntrega.velocidadeAnormal:
        return 'velocidade_anormal';
      case TipoEventoEntrega.perdaSinal:
        return 'perda_sinal';
      case TipoEventoEntrega.recuperacaoSinal:
        return 'recuperacao_sinal';
      case TipoEventoEntrega.entradaGeofence:
        return 'entrada_geofence';
      case TipoEventoEntrega.saidaGeofence:
        return 'saida_geofence';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case TipoEventoEntrega.aceite:
        return 'Entrega Aceita';
      case TipoEventoEntrega.inicioColeta:
        return 'Início da Coleta';
      case TipoEventoEntrega.chegadaColeta:
        return 'Chegada na Origem';
      case TipoEventoEntrega.carregou:
        return 'Carga Carregada';
      case TipoEventoEntrega.inicioRota:
        return 'Início da Rota';
      case TipoEventoEntrega.parada:
        return 'Parada';
      case TipoEventoEntrega.chegadaDestino:
        return 'Chegada no Destino';
      case TipoEventoEntrega.descarregou:
        return 'Carga Descarregada';
      case TipoEventoEntrega.finalizado:
        return 'Entrega Finalizada';
      case TipoEventoEntrega.problema:
        return 'Problema Reportado';
      case TipoEventoEntrega.cancelado:
        return 'Entrega Cancelada';
      case TipoEventoEntrega.desvioRota:
        return 'Desvio de Rota';
      case TipoEventoEntrega.paradaProlongada:
        return 'Parada Prolongada';
      case TipoEventoEntrega.velocidadeAnormal:
        return 'Velocidade Anormal';
      case TipoEventoEntrega.perdaSinal:
        return 'Perda de Sinal GPS';
      case TipoEventoEntrega.recuperacaoSinal:
        return 'Sinal GPS Recuperado';
      case TipoEventoEntrega.entradaGeofence:
        return 'Entrou na Área';
      case TipoEventoEntrega.saidaGeofence:
        return 'Saiu da Área';
    }
  }

  static TipoEventoEntrega fromString(String value) {
    switch (value) {
      case 'inicio_coleta':
        return TipoEventoEntrega.inicioColeta;
      case 'chegada_coleta':
        return TipoEventoEntrega.chegadaColeta;
      case 'inicio_rota':
        return TipoEventoEntrega.inicioRota;
      case 'chegada_destino':
        return TipoEventoEntrega.chegadaDestino;
      case 'desvio_rota':
        return TipoEventoEntrega.desvioRota;
      case 'parada_prolongada':
        return TipoEventoEntrega.paradaProlongada;
      case 'velocidade_anormal':
        return TipoEventoEntrega.velocidadeAnormal;
      case 'perda_sinal':
        return TipoEventoEntrega.perdaSinal;
      case 'recuperacao_sinal':
        return TipoEventoEntrega.recuperacaoSinal;
      case 'entrada_geofence':
        return TipoEventoEntrega.entradaGeofence;
      case 'saida_geofence':
        return TipoEventoEntrega.saidaGeofence;
      case 'aceite':
        return TipoEventoEntrega.aceite;
      case 'carregou':
        return TipoEventoEntrega.carregou;
      case 'parada':
        return TipoEventoEntrega.parada;
      case 'descarregou':
        return TipoEventoEntrega.descarregou;
      case 'finalizado':
        return TipoEventoEntrega.finalizado;
      case 'problema':
        return TipoEventoEntrega.problema;
      case 'cancelado':
        return TipoEventoEntrega.cancelado;
      default:
        return TipoEventoEntrega.aceite;
    }
  }
}
