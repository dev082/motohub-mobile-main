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
  final bool lida;
  final DateTime createdAt;

  Mensagem({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderNome,
    required this.senderTipo,
    required this.conteudo,
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
      lida: lida ?? this.lida,
      createdAt: createdAt ?? this.createdAt,
    );
  }
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
