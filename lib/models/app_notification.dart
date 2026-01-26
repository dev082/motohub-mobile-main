/// App notification model for local notifications
class AppNotification {
  final String id;
  final String? entregaId;
  final String? motoristaId;
  final NotificationType tipo;
  final String titulo;
  final String mensagem;
  final Map<String, dynamic> dados;
  final DateTime enviadaEm;
  final bool lida;

  AppNotification({
    required this.id,
    this.entregaId,
    this.motoristaId,
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    this.dados = const {},
    required this.enviadaEm,
    this.lida = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        entregaId: json['entrega_id'] as String?,
        motoristaId: json['motorista_id'] as String?,
        tipo: NotificationType.fromString(json['tipo'] as String),
        titulo: json['titulo'] as String,
        mensagem: json['mensagem'] as String,
        dados: json['dados'] as Map<String, dynamic>? ?? {},
        enviadaEm: DateTime.parse(json['enviada_em'] as String),
        lida: json['lida'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entrega_id': entregaId,
        'motorista_id': motoristaId,
        'tipo': tipo.value,
        'titulo': titulo,
        'mensagem': mensagem,
        'dados': dados,
        'enviada_em': enviadaEm.toIso8601String(),
        'lida': lida,
      };

  AppNotification copyWith({
    String? id,
    String? entregaId,
    String? motoristaId,
    NotificationType? tipo,
    String? titulo,
    String? mensagem,
    Map<String, dynamic>? dados,
    DateTime? enviadaEm,
    bool? lida,
  }) =>
      AppNotification(
        id: id ?? this.id,
        entregaId: entregaId ?? this.entregaId,
        motoristaId: motoristaId ?? this.motoristaId,
        tipo: tipo ?? this.tipo,
        titulo: titulo ?? this.titulo,
        mensagem: mensagem ?? this.mensagem,
        dados: dados ?? this.dados,
        enviadaEm: enviadaEm ?? this.enviadaEm,
        lida: lida ?? this.lida,
      );
}

enum NotificationType {
  coletaIniciada,
  chegadaOrigem,
  coletaConcluida,
  emTransito,
  chegadaDestino,
  entregaConcluida,
  desvioRota,
  bateriaBaixa,
  offline,
  etaUpdate,
  statusChange;

  String get value {
    switch (this) {
      case NotificationType.coletaIniciada:
        return 'coleta_iniciada';
      case NotificationType.chegadaOrigem:
        return 'chegada_origem';
      case NotificationType.coletaConcluida:
        return 'coleta_concluida';
      case NotificationType.emTransito:
        return 'em_transito';
      case NotificationType.chegadaDestino:
        return 'chegada_destino';
      case NotificationType.entregaConcluida:
        return 'entrega_concluida';
      case NotificationType.desvioRota:
        return 'desvio_rota';
      case NotificationType.bateriaBaixa:
        return 'bateria_baixa';
      case NotificationType.offline:
        return 'offline';
      case NotificationType.etaUpdate:
        return 'eta_update';
      case NotificationType.statusChange:
        return 'status_change';
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.coletaIniciada:
        return 'Coleta Iniciada';
      case NotificationType.chegadaOrigem:
        return 'Chegada na Origem';
      case NotificationType.coletaConcluida:
        return 'Coleta Concluída';
      case NotificationType.emTransito:
        return 'Em Trânsito';
      case NotificationType.chegadaDestino:
        return 'Chegada no Destino';
      case NotificationType.entregaConcluida:
        return 'Entrega Concluída';
      case NotificationType.desvioRota:
        return 'Desvio de Rota';
      case NotificationType.bateriaBaixa:
        return 'Bateria Baixa';
      case NotificationType.offline:
        return 'Offline';
      case NotificationType.etaUpdate:
        return 'Atualização de ETA';
      case NotificationType.statusChange:
        return 'Mudança de Status';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.coletaIniciada:
        return '📦';
      case NotificationType.chegadaOrigem:
        return '📍';
      case NotificationType.coletaConcluida:
        return '✅';
      case NotificationType.emTransito:
        return '🚚';
      case NotificationType.chegadaDestino:
        return '🏁';
      case NotificationType.entregaConcluida:
        return '🎉';
      case NotificationType.desvioRota:
        return '🚨';
      case NotificationType.bateriaBaixa:
        return '🔋';
      case NotificationType.offline:
        return '📶';
      case NotificationType.etaUpdate:
        return '⏱️';
      case NotificationType.statusChange:
        return 'ℹ️';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'coleta_iniciada':
        return NotificationType.coletaIniciada;
      case 'chegada_origem':
        return NotificationType.chegadaOrigem;
      case 'coleta_concluida':
        return NotificationType.coletaConcluida;
      case 'em_transito':
        return NotificationType.emTransito;
      case 'chegada_destino':
        return NotificationType.chegadaDestino;
      case 'entrega_concluida':
        return NotificationType.entregaConcluida;
      case 'desvio_rota':
        return NotificationType.desvioRota;
      case 'bateria_baixa':
        return NotificationType.bateriaBaixa;
      case 'offline':
        return NotificationType.offline;
      case 'eta_update':
        return NotificationType.etaUpdate;
      case 'status_change':
        return NotificationType.statusChange;
      default:
        return NotificationType.statusChange;
    }
  }
}
