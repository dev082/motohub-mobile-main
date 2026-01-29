/// Veiculo model representing vehicle data from Supabase
class Veiculo {
  final String id;
  final String? motoristaId;
  final String placa;
  final TipoVeiculo tipo;
  final TipoCarroceria carroceria;
  /// Quando true, a carroceria é parte do veículo e deve estar referenciada em `carroceriaId`.
  final bool carroceriaIntegrada;
  /// Carroceria vinculada ao veículo quando `carroceriaIntegrada == true`.
  final String? carroceriaId;
  final double? capacidadeKg;
  final double? capacidadeM3;
  final int? ano;
  final String? marca;
  final String? modelo;
  final String? renavam;
  final bool rastreador;
  final bool seguroAtivo;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? empresaId;
  final String? fotoUrl;
  final List<String> fotosUrls;
  final TipoPropriedadeVeiculo? tipoPropriedade;
  final String? uf;
  final String? documentoVeiculoUrl;
  final String? anttRntrc;
  final String? comprovanteEnderecoProprietarioUrl;
  final String? proprietarioCpfCnpj;
  final String? proprietarioNome;

  Veiculo({
    required this.id,
    this.motoristaId,
    required this.placa,
    required this.tipo,
    required this.carroceria,
    this.carroceriaIntegrada = false,
    this.carroceriaId,
    this.capacidadeKg,
    this.capacidadeM3,
    this.ano,
    this.marca,
    this.modelo,
    this.renavam,
    this.rastreador = false,
    this.seguroAtivo = false,
    this.ativo = true,
    required this.createdAt,
    required this.updatedAt,
    this.empresaId,
    this.fotoUrl,
    this.fotosUrls = const [],
    this.tipoPropriedade,
    this.uf,
    this.documentoVeiculoUrl,
    this.anttRntrc,
    this.comprovanteEnderecoProprietarioUrl,
    this.proprietarioCpfCnpj,
    this.proprietarioNome,
  });

  factory Veiculo.fromJson(Map<String, dynamic> json) {
    return Veiculo(
      id: json['id'] as String,
      motoristaId: json['motorista_id'] as String?,
      placa: json['placa'] as String,
      tipo: TipoVeiculo.fromString(json['tipo'] as String),
      carroceria: TipoCarroceria.fromString(json['carroceria'] as String),
      carroceriaIntegrada: json['carroceria_integrada'] as bool? ?? false,
      carroceriaId: json['carroceria_id'] as String?,
      capacidadeKg: json['capacidade_kg'] != null ? (json['capacidade_kg'] as num).toDouble() : null,
      capacidadeM3: json['capacidade_m3'] != null ? (json['capacidade_m3'] as num).toDouble() : null,
      ano: json['ano'] as int?,
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      renavam: json['renavam'] as String?,
      rastreador: json['rastreador'] as bool? ?? false,
      seguroAtivo: json['seguro_ativo'] as bool? ?? false,
      ativo: json['ativo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      empresaId: json['empresa_id'] as int?,
      fotoUrl: json['foto_url'] as String?,
      fotosUrls: _readStringList(json['fotos_urls']),
      tipoPropriedade: json['tipo_propriedade'] != null
          ? TipoPropriedadeVeiculo.fromString(json['tipo_propriedade'] as String)
          : null,
      uf: json['uf'] as String?,
      documentoVeiculoUrl: json['documento_veiculo_url'] as String?,
      anttRntrc: json['antt_rntrc'] as String?,
      comprovanteEnderecoProprietarioUrl: json['comprovante_endereco_proprietario_url'] as String?,
      proprietarioCpfCnpj: json['proprietario_cpf_cnpj'] as String?,
      proprietarioNome: json['proprietario_nome'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'motorista_id': motoristaId,
        'placa': placa,
        'tipo': tipo.value,
        'carroceria': carroceria.value,
        'carroceria_integrada': carroceriaIntegrada,
        'carroceria_id': carroceriaId,
        'capacidade_kg': capacidadeKg,
        'capacidade_m3': capacidadeM3,
        'ano': ano,
        'marca': marca,
        'modelo': modelo,
        'renavam': renavam,
        'rastreador': rastreador,
        'seguro_ativo': seguroAtivo,
        'ativo': ativo,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'empresa_id': empresaId,
        'foto_url': fotoUrl,
        'fotos_urls': fotosUrls,
        'tipo_propriedade': tipoPropriedade?.value,
        'uf': uf,
        'documento_veiculo_url': documentoVeiculoUrl,
        'antt_rntrc': anttRntrc,
        'comprovante_endereco_proprietario_url': comprovanteEnderecoProprietarioUrl,
        'proprietario_cpf_cnpj': proprietarioCpfCnpj,
        'proprietario_nome': proprietarioNome,
      };

  Veiculo copyWith({
    String? id,
    String? motoristaId,
    String? placa,
    TipoVeiculo? tipo,
    TipoCarroceria? carroceria,
    bool? carroceriaIntegrada,
    String? carroceriaId,
    double? capacidadeKg,
    double? capacidadeM3,
    int? ano,
    String? marca,
    String? modelo,
    String? renavam,
    bool? rastreador,
    bool? seguroAtivo,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? empresaId,
    String? fotoUrl,
    List<String>? fotosUrls,
    TipoPropriedadeVeiculo? tipoPropriedade,
    String? uf,
    String? documentoVeiculoUrl,
    String? anttRntrc,
    String? comprovanteEnderecoProprietarioUrl,
    String? proprietarioCpfCnpj,
    String? proprietarioNome,
  }) =>
      Veiculo(
        id: id ?? this.id,
        motoristaId: motoristaId ?? this.motoristaId,
        placa: placa ?? this.placa,
        tipo: tipo ?? this.tipo,
        carroceria: carroceria ?? this.carroceria,
        carroceriaIntegrada: carroceriaIntegrada ?? this.carroceriaIntegrada,
        carroceriaId: carroceriaId ?? this.carroceriaId,
        capacidadeKg: capacidadeKg ?? this.capacidadeKg,
        capacidadeM3: capacidadeM3 ?? this.capacidadeM3,
        ano: ano ?? this.ano,
        marca: marca ?? this.marca,
        modelo: modelo ?? this.modelo,
        renavam: renavam ?? this.renavam,
        rastreador: rastreador ?? this.rastreador,
        seguroAtivo: seguroAtivo ?? this.seguroAtivo,
        ativo: ativo ?? this.ativo,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        empresaId: empresaId ?? this.empresaId,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        fotosUrls: fotosUrls ?? this.fotosUrls,
        tipoPropriedade: tipoPropriedade ?? this.tipoPropriedade,
        uf: uf ?? this.uf,
        documentoVeiculoUrl: documentoVeiculoUrl ?? this.documentoVeiculoUrl,
        anttRntrc: anttRntrc ?? this.anttRntrc,
        comprovanteEnderecoProprietarioUrl: comprovanteEnderecoProprietarioUrl ?? this.comprovanteEnderecoProprietarioUrl,
        proprietarioCpfCnpj: proprietarioCpfCnpj ?? this.proprietarioCpfCnpj,
        proprietarioNome: proprietarioNome ?? this.proprietarioNome,
      );
}

List<String> _readStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  return const [];
}

enum TipoVeiculo {
  truck,
  toco,
  tresQuartos,
  vuc,
  carreta,
  carretaLs,
  bitrem,
  rodotrem,
  vanderleia,
  bitruck;

  String get value {
    switch (this) {
      case TipoVeiculo.tresQuartos:
        return 'tres_quartos';
      case TipoVeiculo.carretaLs:
        return 'carreta_ls';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case TipoVeiculo.truck:
        return 'Truck';
      case TipoVeiculo.toco:
        return 'Toco';
      case TipoVeiculo.tresQuartos:
        return '3/4';
      case TipoVeiculo.vuc:
        return 'VUC';
      case TipoVeiculo.carreta:
        return 'Carreta';
      case TipoVeiculo.carretaLs:
        return 'Carreta LS';
      case TipoVeiculo.bitrem:
        return 'Bitrem';
      case TipoVeiculo.rodotrem:
        return 'Rodotrem';
      case TipoVeiculo.vanderleia:
        return 'Vanderleia';
      case TipoVeiculo.bitruck:
        return 'Bitruck';
    }
  }

  static TipoVeiculo fromString(String value) {
    switch (value) {
      case 'tres_quartos':
        return TipoVeiculo.tresQuartos;
      case 'carreta_ls':
        return TipoVeiculo.carretaLs;
      case 'truck':
        return TipoVeiculo.truck;
      case 'toco':
        return TipoVeiculo.toco;
      case 'vuc':
        return TipoVeiculo.vuc;
      case 'carreta':
        return TipoVeiculo.carreta;
      case 'bitrem':
        return TipoVeiculo.bitrem;
      case 'rodotrem':
        return TipoVeiculo.rodotrem;
      case 'vanderleia':
        return TipoVeiculo.vanderleia;
      case 'bitruck':
        return TipoVeiculo.bitruck;
      default:
        return TipoVeiculo.truck;
    }
  }
}

enum TipoCarroceria {
  aberta,
  fechadaBau,
  graneleira,
  tanque,
  sider,
  frigorifico,
  cegonha,
  prancha,
  container,
  graneleiro,
  gradeBaixa,
  cacamba,
  plataforma,
  bau,
  bauFrigorifico,
  bauRefrigerado,
  silo,
  gaiola,
  bugPortaContainer,
  munk,
  apenasCavalo,
  cavaqueira,
  hopper;

  String get value {
    switch (this) {
      case TipoCarroceria.fechadaBau:
        return 'fechada_bau';
      case TipoCarroceria.gradeBaixa:
        return 'grade_baixa';
      case TipoCarroceria.bauFrigorifico:
        return 'bau_frigorifico';
      case TipoCarroceria.bauRefrigerado:
        return 'bau_refrigerado';
      case TipoCarroceria.bugPortaContainer:
        return 'bug_porta_container';
      case TipoCarroceria.apenasCavalo:
        return 'apenas_cavalo';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case TipoCarroceria.aberta:
        return 'Aberta';
      case TipoCarroceria.fechadaBau:
        return 'Fechada/Baú';
      case TipoCarroceria.graneleira:
        return 'Graneleira';
      case TipoCarroceria.tanque:
        return 'Tanque';
      case TipoCarroceria.sider:
        return 'Sider';
      case TipoCarroceria.frigorifico:
        return 'Frigorífico';
      case TipoCarroceria.cegonha:
        return 'Cegonha';
      case TipoCarroceria.prancha:
        return 'Prancha';
      case TipoCarroceria.container:
        return 'Container';
      case TipoCarroceria.graneleiro:
        return 'Graneleiro';
      case TipoCarroceria.gradeBaixa:
        return 'Grade Baixa';
      case TipoCarroceria.cacamba:
        return 'Caçamba';
      case TipoCarroceria.plataforma:
        return 'Plataforma';
      case TipoCarroceria.bau:
        return 'Baú';
      case TipoCarroceria.bauFrigorifico:
        return 'Baú Frigorífico';
      case TipoCarroceria.bauRefrigerado:
        return 'Baú Refrigerado';
      case TipoCarroceria.silo:
        return 'Silo';
      case TipoCarroceria.gaiola:
        return 'Gaiola';
      case TipoCarroceria.bugPortaContainer:
        return 'Bug Porta Container';
      case TipoCarroceria.munk:
        return 'Munk';
      case TipoCarroceria.apenasCavalo:
        return 'Apenas Cavalo';
      case TipoCarroceria.cavaqueira:
        return 'Cavaqueira';
      case TipoCarroceria.hopper:
        return 'Hopper';
    }
  }

  static TipoCarroceria fromString(String value) {
    switch (value) {
      case 'fechada_bau':
        return TipoCarroceria.fechadaBau;
      case 'grade_baixa':
        return TipoCarroceria.gradeBaixa;
      case 'bau_frigorifico':
        return TipoCarroceria.bauFrigorifico;
      case 'bau_refrigerado':
        return TipoCarroceria.bauRefrigerado;
      case 'bug_porta_container':
        return TipoCarroceria.bugPortaContainer;
      case 'apenas_cavalo':
        return TipoCarroceria.apenasCavalo;
      case 'aberta':
        return TipoCarroceria.aberta;
      case 'graneleira':
        return TipoCarroceria.graneleira;
      case 'tanque':
        return TipoCarroceria.tanque;
      case 'sider':
        return TipoCarroceria.sider;
      case 'frigorifico':
        return TipoCarroceria.frigorifico;
      case 'cegonha':
        return TipoCarroceria.cegonha;
      case 'prancha':
        return TipoCarroceria.prancha;
      case 'container':
        return TipoCarroceria.container;
      case 'graneleiro':
        return TipoCarroceria.graneleiro;
      case 'cacamba':
        return TipoCarroceria.cacamba;
      case 'plataforma':
        return TipoCarroceria.plataforma;
      case 'bau':
        return TipoCarroceria.bau;
      case 'silo':
        return TipoCarroceria.silo;
      case 'gaiola':
        return TipoCarroceria.gaiola;
      case 'munk':
        return TipoCarroceria.munk;
      case 'cavaqueira':
        return TipoCarroceria.cavaqueira;
      case 'hopper':
        return TipoCarroceria.hopper;
      default:
        return TipoCarroceria.aberta;
    }
  }
}

enum TipoPropriedadeVeiculo {
  pf,
  pj;

  String get value => name;

  String get label {
    switch (this) {
      case TipoPropriedadeVeiculo.pf:
        return 'Pessoa Física';
      case TipoPropriedadeVeiculo.pj:
        return 'Pessoa Jurídica';
    }
  }

  static TipoPropriedadeVeiculo fromString(String value) {
    switch (value) {
      case 'pf':
        return TipoPropriedadeVeiculo.pf;
      case 'pj':
        return TipoPropriedadeVeiculo.pj;
      default:
        return TipoPropriedadeVeiculo.pf;
    }
  }
}
