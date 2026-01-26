/// KPIs e Performance do motorista
class MotoristaKPI {
  final String id;
  final String motoristaId;
  final DateTime periodoInicio;
  final DateTime periodoFim;
  final double kmRodado;
  final Duration tempoEmRota;
  final Duration tempoParado;
  final double consumoEstimadoLitros;
  final double custoEstimado;
  final int entregasFinalizadas;
  final int entregasAtrasadas;
  final double taxaAtraso;
  final double mediaPedagios;
  final DateTime createdAt;
  final DateTime updatedAt;

  MotoristaKPI({
    required this.id,
    required this.motoristaId,
    required this.periodoInicio,
    required this.periodoFim,
    this.kmRodado = 0.0,
    this.tempoEmRota = Duration.zero,
    this.tempoParado = Duration.zero,
    this.consumoEstimadoLitros = 0.0,
    this.custoEstimado = 0.0,
    this.entregasFinalizadas = 0,
    this.entregasAtrasadas = 0,
    this.taxaAtraso = 0.0,
    this.mediaPedagios = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MotoristaKPI.fromJson(Map<String, dynamic> json) => MotoristaKPI(
        id: json['id'] as String,
        motoristaId: json['motorista_id'] as String,
        periodoInicio: DateTime.parse(json['periodo_inicio'] as String),
        periodoFim: DateTime.parse(json['periodo_fim'] as String),
        kmRodado: json['km_rodado'] != null ? (json['km_rodado'] as num).toDouble() : 0.0,
        tempoEmRota: Duration(minutes: json['tempo_em_rota_minutos'] as int? ?? 0),
        tempoParado: Duration(minutes: json['tempo_parado_minutos'] as int? ?? 0),
        consumoEstimadoLitros: json['consumo_estimado_litros'] != null ? (json['consumo_estimado_litros'] as num).toDouble() : 0.0,
        custoEstimado: json['custo_estimado'] != null ? (json['custo_estimado'] as num).toDouble() : 0.0,
        entregasFinalizadas: json['entregas_finalizadas'] as int? ?? 0,
        entregasAtrasadas: json['entregas_atrasadas'] as int? ?? 0,
        taxaAtraso: json['taxa_atraso'] != null ? (json['taxa_atraso'] as num).toDouble() : 0.0,
        mediaPedagios: json['media_pedagios'] != null ? (json['media_pedagios'] as num).toDouble() : 0.0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'motorista_id': motoristaId,
        'periodo_inicio': periodoInicio.toIso8601String(),
        'periodo_fim': periodoFim.toIso8601String(),
        'km_rodado': kmRodado,
        'tempo_em_rota_minutos': tempoEmRota.inMinutes,
        'tempo_parado_minutos': tempoParado.inMinutes,
        'consumo_estimado_litros': consumoEstimadoLitros,
        'custo_estimado': custoEstimado,
        'entregas_finalizadas': entregasFinalizadas,
        'entregas_atrasadas': entregasAtrasadas,
        'taxa_atraso': taxaAtraso,
        'media_pedagios': mediaPedagios,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  MotoristaKPI copyWith({
    String? id,
    String? motoristaId,
    DateTime? periodoInicio,
    DateTime? periodoFim,
    double? kmRodado,
    Duration? tempoEmRota,
    Duration? tempoParado,
    double? consumoEstimadoLitros,
    double? custoEstimado,
    int? entregasFinalizadas,
    int? entregasAtrasadas,
    double? taxaAtraso,
    double? mediaPedagios,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MotoristaKPI(
        id: id ?? this.id,
        motoristaId: motoristaId ?? this.motoristaId,
        periodoInicio: periodoInicio ?? this.periodoInicio,
        periodoFim: periodoFim ?? this.periodoFim,
        kmRodado: kmRodado ?? this.kmRodado,
        tempoEmRota: tempoEmRota ?? this.tempoEmRota,
        tempoParado: tempoParado ?? this.tempoParado,
        consumoEstimadoLitros: consumoEstimadoLitros ?? this.consumoEstimadoLitros,
        custoEstimado: custoEstimado ?? this.custoEstimado,
        entregasFinalizadas: entregasFinalizadas ?? this.entregasFinalizadas,
        entregasAtrasadas: entregasAtrasadas ?? this.entregasAtrasadas,
        taxaAtraso: taxaAtraso ?? this.taxaAtraso,
        mediaPedagios: mediaPedagios ?? this.mediaPedagios,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Configuração de custos por veículo
class VeiculoCustoConfig {
  final String veiculoId;
  final double consumoUrbanoKmL;
  final double consumoRodoviarioKmL;
  final double custoPorKm;
  final double pedagioMedio;
  final DateTime updatedAt;

  VeiculoCustoConfig({
    required this.veiculoId,
    this.consumoUrbanoKmL = 4.0,
    this.consumoRodoviarioKmL = 5.5,
    this.custoPorKm = 2.5,
    this.pedagioMedio = 15.0,
    required this.updatedAt,
  });

  factory VeiculoCustoConfig.fromJson(Map<String, dynamic> json) => VeiculoCustoConfig(
        veiculoId: json['veiculo_id'] as String,
        consumoUrbanoKmL: json['consumo_urbano_km_l'] != null ? (json['consumo_urbano_km_l'] as num).toDouble() : 4.0,
        consumoRodoviarioKmL: json['consumo_rodoviario_km_l'] != null ? (json['consumo_rodoviario_km_l'] as num).toDouble() : 5.5,
        custoPorKm: json['custo_por_km'] != null ? (json['custo_por_km'] as num).toDouble() : 2.5,
        pedagioMedio: json['pedagio_medio'] != null ? (json['pedagio_medio'] as num).toDouble() : 15.0,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'veiculo_id': veiculoId,
        'consumo_urbano_km_l': consumoUrbanoKmL,
        'consumo_rodoviario_km_l': consumoRodoviarioKmL,
        'custo_por_km': custoPorKm,
        'pedagio_medio': pedagioMedio,
        'updated_at': updatedAt.toIso8601String(),
      };

  VeiculoCustoConfig copyWith({
    String? veiculoId,
    double? consumoUrbanoKmL,
    double? consumoRodoviarioKmL,
    double? custoPorKm,
    double? pedagioMedio,
    DateTime? updatedAt,
  }) =>
      VeiculoCustoConfig(
        veiculoId: veiculoId ?? this.veiculoId,
        consumoUrbanoKmL: consumoUrbanoKmL ?? this.consumoUrbanoKmL,
        consumoRodoviarioKmL: consumoRodoviarioKmL ?? this.consumoRodoviarioKmL,
        custoPorKm: custoPorKm ?? this.custoPorKm,
        pedagioMedio: pedagioMedio ?? this.pedagioMedio,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
