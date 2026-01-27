/// Chat model for delivery-based messaging
class Chat {
  final String id;
  final String entregaId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Chat({
    required this.id,
    required this.entregaId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      entregaId: json['entrega_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entrega_id': entregaId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Message model for chat messages
class Mensagem {
  final String id;
  final String chatId;
  final String senderId;
  final String senderNome;
  final TipoParticipante senderTipo;
  final String conteudo;
  final String? anexoUrl;
  final String? anexoNome;
  final String? anexoTipo;
  final int? anexoTamanho;
  final bool lida;
  final DateTime createdAt;

  Mensagem({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderNome,
    required this.senderTipo,
    required this.conteudo,
    this.anexoUrl,
    this.anexoNome,
    this.anexoTipo,
    this.anexoTamanho,
    this.lida = false,
    required this.createdAt,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      senderNome: json['sender_nome'] as String,
      senderTipo: TipoParticipante.fromString(json['sender_tipo'] as String),
      conteudo: json['conteudo'] as String,
      anexoUrl: json['anexo_url'] as String?,
      anexoNome: json['anexo_nome'] as String?,
      anexoTipo: json['anexo_tipo'] as String?,
      anexoTamanho: (json['anexo_tamanho'] as num?)?.toInt(),
      lida: json['lida'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat_id': chatId,
        'sender_id': senderId,
        'sender_nome': senderNome,
        'sender_tipo': senderTipo.value,
        'conteudo': conteudo,
        'anexo_url': anexoUrl,
        'anexo_nome': anexoNome,
        'anexo_tipo': anexoTipo,
        'anexo_tamanho': anexoTamanho,
        'lida': lida,
        'created_at': createdAt.toIso8601String(),
      };

  Mensagem copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderNome,
    TipoParticipante? senderTipo,
    String? conteudo,
    String? anexoUrl,
    String? anexoNome,
    String? anexoTipo,
    int? anexoTamanho,
    bool? lida,
    DateTime? createdAt,
  }) {
    return Mensagem(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderNome: senderNome ?? this.senderNome,
      senderTipo: senderTipo ?? this.senderTipo,
      conteudo: conteudo ?? this.conteudo,
      anexoUrl: anexoUrl ?? this.anexoUrl,
      anexoNome: anexoNome ?? this.anexoNome,
      anexoTipo: anexoTipo ?? this.anexoTipo,
      anexoTamanho: anexoTamanho ?? this.anexoTamanho,
      lida: lida ?? this.lida,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Compatibilidade com mensagens antigas onde o anexo era enviado no texto
  /// no formato: `@arquivo.ext`.
  ///
  /// Ex.: `@942862a1-3388-4baa-84a1-e7c4f2f7bb5e.png`
  static final RegExp _legacyAttachmentTag = RegExp(r'^@([^\s]+)$');

  /// Se o conteúdo for somente `@arquivo.ext`, retorna o nome do arquivo.
  String? get legacyAttachmentFileName {
    final raw = conteudo.trim();
    final m = _legacyAttachmentTag.firstMatch(raw);
    if (m == null) return null;
    final name = (m.group(1) ?? '').trim();
    if (name.isEmpty) return null;
    // Garante que parece um arquivo.
    if (!name.contains('.')) return null;
    return name;
  }

  /// Verdadeiro quando não há texto “humano” e o conteúdo é só o tag `@arquivo`.
  bool get isLegacyAttachmentOnly => legacyAttachmentFileName != null;
}

enum TipoParticipante {
  embarcador,
  transportadora,
  motorista;

  String get value => name;

  String get displayName {
    switch (this) {
      case TipoParticipante.embarcador:
        return 'Embarcador';
      case TipoParticipante.transportadora:
        return 'Transportadora';
      case TipoParticipante.motorista:
        return 'Motorista';
    }
  }

  static TipoParticipante fromString(String value) {
    switch (value) {
      case 'embarcador':
        return TipoParticipante.embarcador;
      case 'transportadora':
        return TipoParticipante.transportadora;
      case 'motorista':
        return TipoParticipante.motorista;
      default:
        return TipoParticipante.motorista;
    }
  }
}
