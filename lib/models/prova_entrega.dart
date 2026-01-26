/// Prova de Entrega (POD - Proof of Delivery)
class ProvaEntrega {
  final String id;
  final String entregaId;
  final String? assinaturaUrl;
  final List<String> fotosUrls;
  final String nomeRecebedor;
  final String? documentoRecebedor;
  final DateTime timestamp;
  final ChecklistProvaEntrega checklist;
  final String? observacoes;
  final DateTime createdAt;

  ProvaEntrega({
    required this.id,
    required this.entregaId,
    this.assinaturaUrl,
    this.fotosUrls = const [],
    required this.nomeRecebedor,
    this.documentoRecebedor,
    required this.timestamp,
    required this.checklist,
    this.observacoes,
    required this.createdAt,
  });

  factory ProvaEntrega.fromJson(Map<String, dynamic> json) => ProvaEntrega(
        id: json['id'] as String,
        entregaId: json['entrega_id'] as String,
        assinaturaUrl: json['assinatura_url'] as String?,
        fotosUrls: _readStringList(json['fotos_urls']),
        nomeRecebedor: json['nome_recebedor'] as String,
        documentoRecebedor: json['documento_recebedor'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        checklist: ChecklistProvaEntrega.fromJson(json['checklist'] as Map<String, dynamic>? ?? {}),
        observacoes: json['observacoes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entrega_id': entregaId,
        'assinatura_url': assinaturaUrl,
        'fotos_urls': fotosUrls,
        'nome_recebedor': nomeRecebedor,
        'documento_recebedor': documentoRecebedor,
        'timestamp': timestamp.toIso8601String(),
        'checklist': checklist.toJson(),
        'observacoes': observacoes,
        'created_at': createdAt.toIso8601String(),
      };

  ProvaEntrega copyWith({
    String? id,
    String? entregaId,
    String? assinaturaUrl,
    List<String>? fotosUrls,
    String? nomeRecebedor,
    String? documentoRecebedor,
    DateTime? timestamp,
    ChecklistProvaEntrega? checklist,
    String? observacoes,
    DateTime? createdAt,
  }) =>
      ProvaEntrega(
        id: id ?? this.id,
        entregaId: entregaId ?? this.entregaId,
        assinaturaUrl: assinaturaUrl ?? this.assinaturaUrl,
        fotosUrls: fotosUrls ?? this.fotosUrls,
        nomeRecebedor: nomeRecebedor ?? this.nomeRecebedor,
        documentoRecebedor: documentoRecebedor ?? this.documentoRecebedor,
        timestamp: timestamp ?? this.timestamp,
        checklist: checklist ?? this.checklist,
        observacoes: observacoes ?? this.observacoes,
        createdAt: createdAt ?? this.createdAt,
      );
}

List<String> _readStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const [];
}

/// Checklist de verificação na entrega
class ChecklistProvaEntrega {
  final bool avariasConstatadas;
  final String? descricaoAvarias;
  final bool lacreIntacto;
  final String? numeroLacre;
  final bool quantidadeConferida;
  final int? volumesConferidos;
  final bool notaFiscalPresente;
  final String? numeroNota;

  ChecklistProvaEntrega({
    this.avariasConstatadas = false,
    this.descricaoAvarias,
    this.lacreIntacto = true,
    this.numeroLacre,
    this.quantidadeConferida = true,
    this.volumesConferidos,
    this.notaFiscalPresente = true,
    this.numeroNota,
  });

  factory ChecklistProvaEntrega.fromJson(Map<String, dynamic> json) => ChecklistProvaEntrega(
        avariasConstatadas: json['avarias_constatadas'] as bool? ?? false,
        descricaoAvarias: json['descricao_avarias'] as String?,
        lacreIntacto: json['lacre_intacto'] as bool? ?? true,
        numeroLacre: json['numero_lacre'] as String?,
        quantidadeConferida: json['quantidade_conferida'] as bool? ?? true,
        volumesConferidos: json['volumes_conferidos'] as int?,
        notaFiscalPresente: json['nota_fiscal_presente'] as bool? ?? true,
        numeroNota: json['numero_nota'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'avarias_constatadas': avariasConstatadas,
        'descricao_avarias': descricaoAvarias,
        'lacre_intacto': lacreIntacto,
        'numero_lacre': numeroLacre,
        'quantidade_conferida': quantidadeConferida,
        'volumes_conferidos': volumesConferidos,
        'nota_fiscal_presente': notaFiscalPresente,
        'numero_nota': numeroNota,
      };

  ChecklistProvaEntrega copyWith({
    bool? avariasConstatadas,
    String? descricaoAvarias,
    bool? lacreIntacto,
    String? numeroLacre,
    bool? quantidadeConferida,
    int? volumesConferidos,
    bool? notaFiscalPresente,
    String? numeroNota,
  }) =>
      ChecklistProvaEntrega(
        avariasConstatadas: avariasConstatadas ?? this.avariasConstatadas,
        descricaoAvarias: descricaoAvarias ?? this.descricaoAvarias,
        lacreIntacto: lacreIntacto ?? this.lacreIntacto,
        numeroLacre: numeroLacre ?? this.numeroLacre,
        quantidadeConferida: quantidadeConferida ?? this.quantidadeConferida,
        volumesConferidos: volumesConferidos ?? this.volumesConferidos,
        notaFiscalPresente: notaFiscalPresente ?? this.notaFiscalPresente,
        numeroNota: numeroNota ?? this.numeroNota,
      );
}
