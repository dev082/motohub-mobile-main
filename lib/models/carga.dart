/// Carga model representing freight loads from Supabase
class Carga {
  final String id;
  final String codigo;
  final StatusCarga status;
  final TipoCarga tipo;
  final String descricao;
  final double pesoKg;
  final double? volumeM3;
  final double? valorMercadoria;
  final bool requerRefrigeracao;
  final double? temperaturaMin;
  final double? temperaturaMax;
  final bool cargaPerigosa;
  final String? numeroOnu;
  final bool cargaFragil;
  final bool cargaViva;
  final bool empilhavel;
  final Map<String, dynamic>? veiculoRequisitos;
  final Map<String, dynamic>? comercial;
  final Map<String, dynamic>? documentacao;
  final DateTime? dataColetaDe;
  final DateTime? dataColetaAte;
  final DateTime? dataEntregaLimite;
  final DateTime? publicadaEm;
  final int? empresaId;
  final int? filialId;
  final List<String>? necessidadesEspeciais;
  final String? regrasCarregamento;
  final double? pesoDisponivelKg;
  final bool permiteFracionado;
  final double? valorFreteTonelada;
  final String? enderecoOrigemId;
  final String? enderecoDestinoId;
  final String? destinatarioRazaoSocial;
  final String? destinatarioNomeFantasia;
  final String? destinatarioCnpj;
  final String? destinatarioContatoNome;
  final String? destinatarioContatoTelefone;
  final String? destinatarioContatoEmail;
  final int? quantidadePaletes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos expandidos
  final EnderecoCarga? origem;
  final EnderecoCarga? destino;

  Carga({
    required this.id,
    required this.codigo,
    required this.status,
    required this.tipo,
    required this.descricao,
    required this.pesoKg,
    this.volumeM3,
    this.valorMercadoria,
    this.requerRefrigeracao = false,
    this.temperaturaMin,
    this.temperaturaMax,
    this.cargaPerigosa = false,
    this.numeroOnu,
    this.cargaFragil = false,
    this.cargaViva = false,
    this.empilhavel = true,
    this.veiculoRequisitos,
    this.comercial,
    this.documentacao,
    this.dataColetaDe,
    this.dataColetaAte,
    this.dataEntregaLimite,
    this.publicadaEm,
    this.empresaId,
    this.filialId,
    this.necessidadesEspeciais,
    this.regrasCarregamento,
    this.pesoDisponivelKg,
    this.permiteFracionado = true,
    this.valorFreteTonelada,
    this.enderecoOrigemId,
    this.enderecoDestinoId,
    this.destinatarioRazaoSocial,
    this.destinatarioNomeFantasia,
    this.destinatarioCnpj,
    this.destinatarioContatoNome,
    this.destinatarioContatoTelefone,
    this.destinatarioContatoEmail,
    this.quantidadePaletes,
    required this.createdAt,
    required this.updatedAt,
    this.origem,
    this.destino,
  });

  factory Carga.fromJson(Map<String, dynamic> json) {
    return Carga(
      id: json['id'] as String,
      codigo: json['codigo'] as String,
      status: StatusCarga.fromString(json['status'] as String? ?? 'publicada'),
      tipo: TipoCarga.fromString(json['tipo'] as String),
      descricao: json['descricao'] as String,
      pesoKg: (json['peso_kg'] as num).toDouble(),
      volumeM3: json['volume_m3'] != null ? (json['volume_m3'] as num).toDouble() : null,
      valorMercadoria: json['valor_mercadoria'] != null ? (json['valor_mercadoria'] as num).toDouble() : null,
      requerRefrigeracao: json['requer_refrigeracao'] as bool? ?? false,
      temperaturaMin: json['temperatura_min'] != null ? (json['temperatura_min'] as num).toDouble() : null,
      temperaturaMax: json['temperatura_max'] != null ? (json['temperatura_max'] as num).toDouble() : null,
      cargaPerigosa: json['carga_perigosa'] as bool? ?? false,
      numeroOnu: json['numero_onu'] as String?,
      cargaFragil: json['carga_fragil'] as bool? ?? false,
      cargaViva: json['carga_viva'] as bool? ?? false,
      empilhavel: json['empilhavel'] as bool? ?? true,
      veiculoRequisitos: json['veiculo_requisitos'] as Map<String, dynamic>?,
      comercial: json['comercial'] as Map<String, dynamic>?,
      documentacao: json['documentacao'] as Map<String, dynamic>?,
      dataColetaDe: json['data_coleta_de'] != null ? DateTime.parse(json['data_coleta_de'] as String) : null,
      dataColetaAte: json['data_coleta_ate'] != null ? DateTime.parse(json['data_coleta_ate'] as String) : null,
      dataEntregaLimite: json['data_entrega_limite'] != null ? DateTime.parse(json['data_entrega_limite'] as String) : null,
      publicadaEm: json['publicada_em'] != null ? DateTime.parse(json['publicada_em'] as String) : null,
      empresaId: json['empresa_id'] as int?,
      filialId: json['filial_id'] as int?,
      necessidadesEspeciais: json['necessidades_especiais'] != null 
          ? List<String>.from(json['necessidades_especiais'] as List)
          : null,
      regrasCarregamento: json['regras_carregamento'] as String?,
      pesoDisponivelKg: json['peso_disponivel_kg'] != null ? (json['peso_disponivel_kg'] as num).toDouble() : null,
      permiteFracionado: json['permite_fracionado'] as bool? ?? true,
      valorFreteTonelada: json['valor_frete_tonelada'] != null ? (json['valor_frete_tonelada'] as num).toDouble() : null,
      enderecoOrigemId: json['endereco_origem_id'] as String?,
      enderecoDestinoId: json['endereco_destino_id'] as String?,
      destinatarioRazaoSocial: json['destinatario_razao_social'] as String?,
      destinatarioNomeFantasia: json['destinatario_nome_fantasia'] as String?,
      destinatarioCnpj: json['destinatario_cnpj'] as String?,
      destinatarioContatoNome: json['destinatario_contato_nome'] as String?,
      destinatarioContatoTelefone: json['destinatario_contato_telefone'] as String?,
      destinatarioContatoEmail: json['destinatario_contato_email'] as String?,
      quantidadePaletes: json['quantidade_paletes'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      origem: json['origem'] != null ? EnderecoCarga.fromJson(json['origem'] as Map<String, dynamic>) : null,
      destino: json['destino'] != null ? EnderecoCarga.fromJson(json['destino'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo': codigo,
        'status': status.value,
        'tipo': tipo.value,
        'descricao': descricao,
        'peso_kg': pesoKg,
        'volume_m3': volumeM3,
        'valor_mercadoria': valorMercadoria,
        'requer_refrigeracao': requerRefrigeracao,
        'temperatura_min': temperaturaMin,
        'temperatura_max': temperaturaMax,
        'carga_perigosa': cargaPerigosa,
        'numero_onu': numeroOnu,
        'carga_fragil': cargaFragil,
        'carga_viva': cargaViva,
        'empilhavel': empilhavel,
        'veiculo_requisitos': veiculoRequisitos,
        'comercial': comercial,
        'documentacao': documentacao,
        'data_coleta_de': dataColetaDe?.toIso8601String(),
        'data_coleta_ate': dataColetaAte?.toIso8601String(),
        'data_entrega_limite': dataEntregaLimite?.toIso8601String(),
        'publicada_em': publicadaEm?.toIso8601String(),
        'empresa_id': empresaId,
        'filial_id': filialId,
        'necessidades_especiais': necessidadesEspeciais,
        'regras_carregamento': regrasCarregamento,
        'peso_disponivel_kg': pesoDisponivelKg,
        'permite_fracionado': permiteFracionado,
        'valor_frete_tonelada': valorFreteTonelada,
        'endereco_origem_id': enderecoOrigemId,
        'endereco_destino_id': enderecoDestinoId,
        'destinatario_razao_social': destinatarioRazaoSocial,
        'destinatario_nome_fantasia': destinatarioNomeFantasia,
        'destinatario_cnpj': destinatarioCnpj,
        'destinatario_contato_nome': destinatarioContatoNome,
        'destinatario_contato_telefone': destinatarioContatoTelefone,
        'destinatario_contato_email': destinatarioContatoEmail,
        'quantidade_paletes': quantidadePaletes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

enum StatusCarga {
  publicada,
  parcialmenteAlocada,
  totalmenteAlocada;

  String get value {
    switch (this) {
      case StatusCarga.publicada:
        return 'publicada';
      case StatusCarga.parcialmenteAlocada:
        return 'parcialmente_alocada';
      case StatusCarga.totalmenteAlocada:
        return 'totalmente_alocada';
    }
  }

  static StatusCarga fromString(String value) {
    switch (value) {
      case 'publicada':
        return StatusCarga.publicada;
      case 'parcialmente_alocada':
        return StatusCarga.parcialmenteAlocada;
      case 'totalmente_alocada':
        return StatusCarga.totalmenteAlocada;
      default:
        return StatusCarga.publicada;
    }
  }
}

enum TipoCarga {
  granelSolido,
  granelLiquido,
  cargaSeca,
  refrigerada,
  congelada,
  perigosa,
  viva,
  indivisivel,
  container;

  String get value {
    switch (this) {
      case TipoCarga.granelSolido:
        return 'granel_solido';
      case TipoCarga.granelLiquido:
        return 'granel_liquido';
      case TipoCarga.cargaSeca:
        return 'carga_seca';
      case TipoCarga.refrigerada:
        return 'refrigerada';
      case TipoCarga.congelada:
        return 'congelada';
      case TipoCarga.perigosa:
        return 'perigosa';
      case TipoCarga.viva:
        return 'viva';
      case TipoCarga.indivisivel:
        return 'indivisivel';
      case TipoCarga.container:
        return 'container';
    }
  }

  String get displayName {
    switch (this) {
      case TipoCarga.granelSolido:
        return 'Granel Sólido';
      case TipoCarga.granelLiquido:
        return 'Granel Líquido';
      case TipoCarga.cargaSeca:
        return 'Carga Seca';
      case TipoCarga.refrigerada:
        return 'Refrigerada';
      case TipoCarga.congelada:
        return 'Congelada';
      case TipoCarga.perigosa:
        return 'Perigosa';
      case TipoCarga.viva:
        return 'Viva';
      case TipoCarga.indivisivel:
        return 'Indivisível';
      case TipoCarga.container:
        return 'Container';
    }
  }

  static TipoCarga fromString(String value) {
    switch (value) {
      case 'granel_solido':
        return TipoCarga.granelSolido;
      case 'granel_liquido':
        return TipoCarga.granelLiquido;
      case 'carga_seca':
        return TipoCarga.cargaSeca;
      case 'refrigerada':
        return TipoCarga.refrigerada;
      case 'congelada':
        return TipoCarga.congelada;
      case 'perigosa':
        return TipoCarga.perigosa;
      case 'viva':
        return TipoCarga.viva;
      case 'indivisivel':
        return TipoCarga.indivisivel;
      case 'container':
        return TipoCarga.container;
      default:
        return TipoCarga.cargaSeca;
    }
  }
}

/// Endereço de carga (origem ou destino)
class EnderecoCarga {
  final String id;
  final TipoEndereco tipo;
  final String cep;
  final String logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String cidade;
  final String estado;
  final double? latitude;
  final double? longitude;
  final String? contatoNome;
  final String? contatoTelefone;
  final String? contatoEmail;

  EnderecoCarga({
    required this.id,
    required this.tipo,
    required this.cep,
    required this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    required this.cidade,
    required this.estado,
    this.latitude,
    this.longitude,
    this.contatoNome,
    this.contatoTelefone,
    this.contatoEmail,
  });

  factory EnderecoCarga.fromJson(Map<String, dynamic> json) {
    return EnderecoCarga(
      id: json['id'] as String,
      tipo: TipoEndereco.fromString(json['tipo'] as String),
      cep: json['cep'] as String,
      logradouro: json['logradouro'] as String,
      numero: json['numero'] as String?,
      complemento: json['complemento'] as String?,
      bairro: json['bairro'] as String?,
      cidade: json['cidade'] as String,
      estado: json['estado'] as String,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      contatoNome: json['contato_nome'] as String?,
      contatoTelefone: json['contato_telefone'] as String?,
      contatoEmail: json['contato_email'] as String?,
    );
  }

  String get enderecoCompleto {
    final parts = <String>[];
    parts.add(logradouro);
    if (numero != null && numero!.isNotEmpty) parts.add(numero!);
    if (bairro != null && bairro!.isNotEmpty) parts.add(bairro!);
    parts.add('$cidade - $estado');
    return parts.join(', ');
  }
}

enum TipoEndereco {
  origem,
  destino;

  String get value => name;

  static TipoEndereco fromString(String value) {
    switch (value) {
      case 'origem':
        return TipoEndereco.origem;
      case 'destino':
        return TipoEndereco.destino;
      default:
        return TipoEndereco.origem;
    }
  }
}
