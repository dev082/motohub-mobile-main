/// Documento com validade e alertas de vencimento
class DocumentoValidacao {
  final String id;
  final String? motoristaId;
  final String? veiculoId;
  final String? carroceriaId;
  final TipoDocumento tipo;
  final String numero;
  final String? url;
  final DateTime? dataEmissao;
  final DateTime? dataVencimento;
  final StatusDocumento status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentoValidacao({
    required this.id,
    this.motoristaId,
    this.veiculoId,
    this.carroceriaId,
    required this.tipo,
    required this.numero,
    this.url,
    this.dataEmissao,
    this.dataVencimento,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Verifica se o documento está vencido ou próximo do vencimento
  StatusDocumento get statusCalculado {
    if (dataVencimento == null) return StatusDocumento.ok;
    final now = DateTime.now();
    final diff = dataVencimento!.difference(now).inDays;
    if (diff < 0) return StatusDocumento.vencido;
    if (diff <= 7) return StatusDocumento.vence7Dias;
    if (diff <= 15) return StatusDocumento.vence15Dias;
    if (diff <= 30) return StatusDocumento.vence30Dias;
    return StatusDocumento.ok;
  }

  factory DocumentoValidacao.fromJson(Map<String, dynamic> json) => DocumentoValidacao(
        id: json['id'] as String,
        motoristaId: json['motorista_id'] as String?,
        veiculoId: json['veiculo_id'] as String?,
        carroceriaId: json['carroceria_id'] as String?,
        tipo: TipoDocumento.fromString(json['tipo'] as String),
        numero: json['numero'] as String,
        url: json['url'] as String?,
        dataEmissao: json['data_emissao'] != null ? DateTime.parse(json['data_emissao'] as String) : null,
        dataVencimento: json['data_vencimento'] != null ? DateTime.parse(json['data_vencimento'] as String) : null,
        status: StatusDocumento.fromString(json['status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'motorista_id': motoristaId,
        'veiculo_id': veiculoId,
        'carroceria_id': carroceriaId,
        'tipo': tipo.value,
        'numero': numero,
        'url': url,
        'data_emissao': dataEmissao?.toIso8601String(),
        'data_vencimento': dataVencimento?.toIso8601String(),
        'status': status.value,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  DocumentoValidacao copyWith({
    String? id,
    String? motoristaId,
    String? veiculoId,
    String? carroceriaId,
    TipoDocumento? tipo,
    String? numero,
    String? url,
    DateTime? dataEmissao,
    DateTime? dataVencimento,
    StatusDocumento? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      DocumentoValidacao(
        id: id ?? this.id,
        motoristaId: motoristaId ?? this.motoristaId,
        veiculoId: veiculoId ?? this.veiculoId,
        carroceriaId: carroceriaId ?? this.carroceriaId,
        tipo: tipo ?? this.tipo,
        numero: numero ?? this.numero,
        url: url ?? this.url,
        dataEmissao: dataEmissao ?? this.dataEmissao,
        dataVencimento: dataVencimento ?? this.dataVencimento,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

enum TipoDocumento {
  cnh,
  crlv,
  antt,
  seguro,
  tacografo,
  outro;

  String get value => name;

  String get displayName {
    switch (this) {
      case TipoDocumento.cnh:
        return 'CNH';
      case TipoDocumento.crlv:
        return 'CRLV';
      case TipoDocumento.antt:
        return 'ANTT';
      case TipoDocumento.seguro:
        return 'Seguro';
      case TipoDocumento.tacografo:
        return 'Tacógrafo';
      case TipoDocumento.outro:
        return 'Outro';
    }
  }

  static TipoDocumento fromString(String value) {
    switch (value) {
      case 'cnh':
        return TipoDocumento.cnh;
      case 'crlv':
        return TipoDocumento.crlv;
      case 'antt':
        return TipoDocumento.antt;
      case 'seguro':
        return TipoDocumento.seguro;
      case 'tacografo':
        return TipoDocumento.tacografo;
      case 'outro':
        return TipoDocumento.outro;
      default:
        return TipoDocumento.outro;
    }
  }
}

enum StatusDocumento {
  ok,
  vence30Dias,
  vence15Dias,
  vence7Dias,
  vencido,
  pendente;

  String get value {
    switch (this) {
      case StatusDocumento.vence30Dias:
        return 'vence_30_dias';
      case StatusDocumento.vence15Dias:
        return 'vence_15_dias';
      case StatusDocumento.vence7Dias:
        return 'vence_7_dias';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case StatusDocumento.ok:
        return 'OK';
      case StatusDocumento.vence30Dias:
        return 'Vence em 30 dias';
      case StatusDocumento.vence15Dias:
        return 'Vence em 15 dias';
      case StatusDocumento.vence7Dias:
        return 'Vence em 7 dias';
      case StatusDocumento.vencido:
        return 'Vencido';
      case StatusDocumento.pendente:
        return 'Pendente';
    }
  }

  static StatusDocumento fromString(String value) {
    switch (value) {
      case 'vence_30_dias':
        return StatusDocumento.vence30Dias;
      case 'vence_15_dias':
        return StatusDocumento.vence15Dias;
      case 'vence_7_dias':
        return StatusDocumento.vence7Dias;
      case 'vencido':
        return StatusDocumento.vencido;
      case 'pendente':
        return StatusDocumento.pendente;
      case 'ok':
        return StatusDocumento.ok;
      default:
        return StatusDocumento.pendente;
    }
  }
}
