import 'package:supabase_flutter/supabase_flutter.dart';

/// Motorista model representing driver data from Supabase
class Motorista {
  final String id;
  final String? userId;
  final String nomeCompleto;
  final String cpf;
  final String? cnh;
  final String? categoriaCnh;
  final DateTime? validadeCnh;
  final String? telefone;
  final String? email;
  final String? fotoUrl;
  final bool ativo;
  final int? empresaId;
  final String? pushToken;
  final TipoCadastroMotorista tipoCadastro;
  final String? uf;
  final DateTime createdAt;
  final DateTime updatedAt;

  Motorista({
    required this.id,
    this.userId,
    required this.nomeCompleto,
    required this.cpf,
    this.cnh,
    this.categoriaCnh,
    this.validadeCnh,
    this.telefone,
    this.email,
    this.fotoUrl,
    this.ativo = true,
    this.empresaId,
    this.pushToken,
    this.tipoCadastro = TipoCadastroMotorista.autonomo,
    this.uf,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True quando o motorista é cadastrado como autônomo.
  ///
  /// Importante: em alguns cenários o backend pode preencher `empresa_id` mesmo
  /// para motoristas autônomos (ex.: empresa "hub"/default). Então a fonte de
  /// verdade aqui é `tipoCadastro`.
  bool get isAutonomo => tipoCadastro == TipoCadastroMotorista.autonomo;

  /// True quando o motorista é cadastrado como frota.
  bool get isFrota => tipoCadastro == TipoCadastroMotorista.frota;

  /// Indica se existe uma empresa vinculada (quando aplicável).
  bool get hasEmpresa => empresaId != null;

  factory Motorista.fromJson(Map<String, dynamic> json) {
    final rawEmpresaId = json['empresa_id'];
    final normalizedEmpresaId = (rawEmpresaId is int && rawEmpresaId == 0) ? null : rawEmpresaId as int?;
    return Motorista(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      nomeCompleto: json['nome_completo'] as String,
      cpf: json['cpf'] as String,
      cnh: json['cnh'] as String?,
      categoriaCnh: json['categoria_cnh'] as String?,
      validadeCnh: json['validade_cnh'] != null
          ? DateTime.parse(json['validade_cnh'] as String)
          : null,
      telefone: json['telefone'] as String?,
      email: json['email'] as String?,
      fotoUrl: json['foto_url'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      empresaId: normalizedEmpresaId,
      pushToken: json['push_token'] as String?,
      tipoCadastro: TipoCadastroMotorista.fromString(
        json['tipo_cadastro'] as String? ?? 'autonomo',
      ),
      uf: json['uf'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'nome_completo': nomeCompleto,
        'cpf': cpf,
        'cnh': cnh,
        'categoria_cnh': categoriaCnh,
        'validade_cnh': validadeCnh?.toIso8601String(),
        'telefone': telefone,
        'email': email,
        'foto_url': fotoUrl,
        'ativo': ativo,
        'empresa_id': empresaId,
        'push_token': pushToken,
        'tipo_cadastro': tipoCadastro.value,
        'uf': uf,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Motorista copyWith({
    String? id,
    String? userId,
    String? nomeCompleto,
    String? cpf,
    String? cnh,
    String? categoriaCnh,
    DateTime? validadeCnh,
    String? telefone,
    String? email,
    String? fotoUrl,
    bool? ativo,
    int? empresaId,
    String? pushToken,
    TipoCadastroMotorista? tipoCadastro,
    String? uf,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Motorista(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      cpf: cpf ?? this.cpf,
      cnh: cnh ?? this.cnh,
      categoriaCnh: categoriaCnh ?? this.categoriaCnh,
      validadeCnh: validadeCnh ?? this.validadeCnh,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      ativo: ativo ?? this.ativo,
      empresaId: empresaId ?? this.empresaId,
      pushToken: pushToken ?? this.pushToken,
      tipoCadastro: tipoCadastro ?? this.tipoCadastro,
      uf: uf ?? this.uf,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum TipoCadastroMotorista {
  autonomo,
  frota;

  String get value => name;

  static TipoCadastroMotorista fromString(String value) {
    switch (value) {
      case 'autonomo':
        return TipoCadastroMotorista.autonomo;
      case 'frota':
        return TipoCadastroMotorista.frota;
      default:
        return TipoCadastroMotorista.autonomo;
    }
  }
}
