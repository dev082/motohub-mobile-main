import 'package:hubfrete/models/carga.dart';
import 'package:hubfrete/models/checklist_veiculo.dart';

/// Entrega model representing delivery assignments from Supabase
class Entrega {
  final String id;
  final String cargaId;
  final String? motoristaId;
  final String? veiculoId;
  final String? carroceriaId;
  final StatusEntrega status;
  final DateTime? coletadoEm;
  final DateTime? entregueEm;
  final String? fotoComprovanteColeta;
  final String? fotoComprovanteEntrega;
  final String? assinaturaRecebedor;
  final String? nomeRecebedor;
  final String? documentoRecebedor;
  final String? observacoes;
  final double? pesoAlocadoKg;
  final double? valorFrete;
  final String? codigo;
  final String? cteUrl;
  final String? canhotoUrl;
  final ChecklistVeiculo? checklistVeiculo;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos expandidos
  final Carga? carga;

  Entrega({
    required this.id,
    required this.cargaId,
    this.motoristaId,
    this.veiculoId,
    this.carroceriaId,
    this.status = StatusEntrega.aguardando,
    this.coletadoEm,
    this.entregueEm,
    this.fotoComprovanteColeta,
    this.fotoComprovanteEntrega,
    this.assinaturaRecebedor,
    this.nomeRecebedor,
    this.documentoRecebedor,
    this.observacoes,
    this.pesoAlocadoKg,
    this.valorFrete,
    this.codigo,
    this.cteUrl,
    this.canhotoUrl,
    this.checklistVeiculo,
    required this.createdAt,
    required this.updatedAt,
    this.carga,
  });

  factory Entrega.fromJson(Map<String, dynamic> json) {
    return Entrega(
      id: json['id'] as String,
      cargaId: json['carga_id'] as String,
      motoristaId: json['motorista_id'] as String?,
      veiculoId: json['veiculo_id'] as String?,
      carroceriaId: json['carroceria_id'] as String?,
      status: StatusEntrega.fromString(json['status'] as String? ?? 'aguardando'),
      coletadoEm: json['coletado_em'] != null ? DateTime.parse(json['coletado_em'] as String) : null,
      entregueEm: json['entregue_em'] != null ? DateTime.parse(json['entregue_em'] as String) : null,
      fotoComprovanteColeta: json['foto_comprovante_coleta'] as String?,
      fotoComprovanteEntrega: json['foto_comprovante_entrega'] as String?,
      assinaturaRecebedor: json['assinatura_recebedor'] as String?,
      nomeRecebedor: json['nome_recebedor'] as String?,
      documentoRecebedor: json['documento_recebedor'] as String?,
      observacoes: json['observacoes'] as String?,
      pesoAlocadoKg: json['peso_alocado_kg'] != null ? (json['peso_alocado_kg'] as num).toDouble() : null,
      valorFrete: json['valor_frete'] != null ? (json['valor_frete'] as num).toDouble() : null,
      codigo: json['codigo'] as String?,
      cteUrl: json['cte_url'] as String?,
      canhotoUrl: json['canhoto_url'] as String?,
      checklistVeiculo: json['checklist_veiculo'] != null ? ChecklistVeiculo.fromJson(json['checklist_veiculo'] as Map<String, dynamic>) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      carga: json['carga'] != null ? Carga.fromJson(json['carga'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'carga_id': cargaId,
        'motorista_id': motoristaId,
        'veiculo_id': veiculoId,
        'carroceria_id': carroceriaId,
        'status': status.value,
        'coletado_em': coletadoEm?.toIso8601String(),
        'entregue_em': entregueEm?.toIso8601String(),
        'foto_comprovante_coleta': fotoComprovanteColeta,
        'foto_comprovante_entrega': fotoComprovanteEntrega,
        'assinatura_recebedor': assinaturaRecebedor,
        'nome_recebedor': nomeRecebedor,
        'documento_recebedor': documentoRecebedor,
        'observacoes': observacoes,
        'peso_alocado_kg': pesoAlocadoKg,
        'valor_frete': valorFrete,
        'codigo': codigo,
        'cte_url': cteUrl,
        'canhoto_url': canhotoUrl,
        'checklist_veiculo': checklistVeiculo?.toJson(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Entrega copyWith({
    String? id,
    String? cargaId,
    String? motoristaId,
    String? veiculoId,
    String? carroceriaId,
    StatusEntrega? status,
    DateTime? coletadoEm,
    DateTime? entregueEm,
    String? fotoComprovanteColeta,
    String? fotoComprovanteEntrega,
    String? assinaturaRecebedor,
    String? nomeRecebedor,
    String? documentoRecebedor,
    String? observacoes,
    double? pesoAlocadoKg,
    double? valorFrete,
    String? codigo,
    String? cteUrl,
    String? canhotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    Carga? carga,
  }) {
    return Entrega(
      id: id ?? this.id,
      cargaId: cargaId ?? this.cargaId,
      motoristaId: motoristaId ?? this.motoristaId,
      veiculoId: veiculoId ?? this.veiculoId,
      carroceriaId: carroceriaId ?? this.carroceriaId,
      status: status ?? this.status,
      coletadoEm: coletadoEm ?? this.coletadoEm,
      entregueEm: entregueEm ?? this.entregueEm,
      fotoComprovanteColeta: fotoComprovanteColeta ?? this.fotoComprovanteColeta,
      fotoComprovanteEntrega: fotoComprovanteEntrega ?? this.fotoComprovanteEntrega,
      assinaturaRecebedor: assinaturaRecebedor ?? this.assinaturaRecebedor,
      nomeRecebedor: nomeRecebedor ?? this.nomeRecebedor,
      documentoRecebedor: documentoRecebedor ?? this.documentoRecebedor,
      observacoes: observacoes ?? this.observacoes,
      pesoAlocadoKg: pesoAlocadoKg ?? this.pesoAlocadoKg,
      valorFrete: valorFrete ?? this.valorFrete,
      codigo: codigo ?? this.codigo,
      cteUrl: cteUrl ?? this.cteUrl,
      canhotoUrl: canhotoUrl ?? this.canhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      carga: carga ?? this.carga,
    );
  }
}

enum StatusEntrega {
  /// A entrega foi criada/atribuída e ainda não saiu para coleta.
  aguardando,

  /// O motorista saiu para realizar a coleta.
  saiuParaColeta,

  /// O motorista já está com a carga e saiu para realizar a entrega.
  saiuParaEntrega,

  /// Entrega concluída.
  entregue,

  /// Ocorreu algum problema e a entrega não seguiu o fluxo normal.
  problema,

  /// Entrega cancelada.
  cancelada;

  String get value {
    switch (this) {
      case StatusEntrega.aguardando:
        return 'aguardando';
      case StatusEntrega.saiuParaColeta:
        return 'saiu_para_coleta';
      case StatusEntrega.saiuParaEntrega:
        return 'saiu_para_entrega';
      case StatusEntrega.entregue:
        return 'entregue';
      case StatusEntrega.problema:
        return 'problema';
      case StatusEntrega.cancelada:
        return 'cancelada';
    }
  }

  String get displayName {
    switch (this) {
      case StatusEntrega.aguardando:
        return 'Aguardando';
      case StatusEntrega.saiuParaColeta:
        return 'Saiu para coleta';
      case StatusEntrega.saiuParaEntrega:
        return 'Saiu para entrega';
      case StatusEntrega.entregue:
        return 'Entregue';
      case StatusEntrega.problema:
        return 'Problema';
      case StatusEntrega.cancelada:
        return 'Cancelada';
    }
  }

  static StatusEntrega fromString(String value) {
    switch (value) {
      // Novo enum (válido no Supabase)
      case 'aguardando':
        return StatusEntrega.aguardando;
      case 'saiu_para_coleta':
        return StatusEntrega.saiuParaColeta;
      case 'saiu_para_entrega':
        return StatusEntrega.saiuParaEntrega;
      case 'entregue':
        return StatusEntrega.entregue;
      case 'problema':
        return StatusEntrega.problema;
      case 'cancelada':
        return StatusEntrega.cancelada;

      // Compatibilidade (caso existam registros legados no ambiente)
      case 'aguardando_coleta':
        return StatusEntrega.aguardando;
      case 'em_coleta':
      case 'coletado':
      case 'em_transito':
        return StatusEntrega.saiuParaColeta;
      case 'em_entrega':
        return StatusEntrega.saiuParaEntrega;
      default:
        return StatusEntrega.aguardando;
    }
  }
}
