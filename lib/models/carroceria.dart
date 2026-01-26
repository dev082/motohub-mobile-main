/// Carroceria model representing trailer data from Supabase
class Carroceria {
  final String id;
  final String placa;
  final String tipo;
  final String? marca;
  final String? modelo;
  final int? ano;
  final String? renavam;
  final double? capacidadeKg;
  final double? capacidadeM3;
  final String? fotoUrl;
  final List<String> fotosUrls;
  final bool ativo;
  final int? empresaId;
  final String? motoristaId;
  final String? uf;
  final String? documentoCarroceriaUrl;
  final String? anttRntrc;
  final String? comprovanteEnderecoProprietarioUrl;
  final String? tipoPropriedade;
  final DateTime createdAt;
  final DateTime updatedAt;

  Carroceria({
    required this.id,
    required this.placa,
    required this.tipo,
    this.marca,
    this.modelo,
    this.ano,
    this.renavam,
    this.capacidadeKg,
    this.capacidadeM3,
    this.fotoUrl,
    this.fotosUrls = const [],
    this.ativo = true,
    this.empresaId,
    this.motoristaId,
    this.uf,
    this.documentoCarroceriaUrl,
    this.anttRntrc,
    this.comprovanteEnderecoProprietarioUrl,
    this.tipoPropriedade,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Carroceria.fromJson(Map<String, dynamic> json) {
    return Carroceria(
      id: json['id'] as String,
      placa: json['placa'] as String,
      tipo: json['tipo'] as String,
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String?,
      ano: json['ano'] as int?,
      renavam: json['renavam'] as String?,
      capacidadeKg: json['capacidade_kg'] != null ? (json['capacidade_kg'] as num).toDouble() : null,
      capacidadeM3: json['capacidade_m3'] != null ? (json['capacidade_m3'] as num).toDouble() : null,
      fotoUrl: json['foto_url'] as String?,
      fotosUrls: _readStringList(json['fotos_urls']),
      ativo: json['ativo'] as bool? ?? true,
      empresaId: json['empresa_id'] as int?,
      motoristaId: json['motorista_id'] as String?,
      uf: json['uf'] as String?,
      documentoCarroceriaUrl: json['documento_carroceria_url'] as String?,
      anttRntrc: json['antt_rntrc'] as String?,
      comprovanteEnderecoProprietarioUrl: json['comprovante_endereco_proprietario_url'] as String?,
      tipoPropriedade: json['tipo_propriedade'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'placa': placa,
        'tipo': tipo,
        'marca': marca,
        'modelo': modelo,
        'ano': ano,
        'renavam': renavam,
        'capacidade_kg': capacidadeKg,
        'capacidade_m3': capacidadeM3,
        'foto_url': fotoUrl,
        'fotos_urls': fotosUrls,
        'ativo': ativo,
        'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'uf': uf,
        'documento_carroceria_url': documentoCarroceriaUrl,
        'antt_rntrc': anttRntrc,
        'comprovante_endereco_proprietario_url': comprovanteEnderecoProprietarioUrl,
        'tipo_propriedade': tipoPropriedade,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Carroceria copyWith({
    String? id,
    String? placa,
    String? tipo,
    String? marca,
    String? modelo,
    int? ano,
    String? renavam,
    double? capacidadeKg,
    double? capacidadeM3,
    String? fotoUrl,
    List<String>? fotosUrls,
    bool? ativo,
    int? empresaId,
    String? motoristaId,
    String? uf,
    String? documentoCarroceriaUrl,
    String? anttRntrc,
    String? comprovanteEnderecoProprietarioUrl,
    String? tipoPropriedade,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Carroceria(
        id: id ?? this.id,
        placa: placa ?? this.placa,
        tipo: tipo ?? this.tipo,
        marca: marca ?? this.marca,
        modelo: modelo ?? this.modelo,
        ano: ano ?? this.ano,
        renavam: renavam ?? this.renavam,
        capacidadeKg: capacidadeKg ?? this.capacidadeKg,
        capacidadeM3: capacidadeM3 ?? this.capacidadeM3,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        fotosUrls: fotosUrls ?? this.fotosUrls,
        ativo: ativo ?? this.ativo,
        empresaId: empresaId ?? this.empresaId,
        motoristaId: motoristaId ?? this.motoristaId,
        uf: uf ?? this.uf,
        documentoCarroceriaUrl: documentoCarroceriaUrl ?? this.documentoCarroceriaUrl,
        anttRntrc: anttRntrc ?? this.anttRntrc,
        comprovanteEnderecoProprietarioUrl: comprovanteEnderecoProprietarioUrl ?? this.comprovanteEnderecoProprietarioUrl,
        tipoPropriedade: tipoPropriedade ?? this.tipoPropriedade,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

List<String> _readStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  return const [];
}
