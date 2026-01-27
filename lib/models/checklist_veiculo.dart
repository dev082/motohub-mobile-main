/// Checklist de verificação do veículo antes de iniciar uma entrega
class ChecklistVeiculo {
  final bool pneusOk;
  final bool freiosOk;
  final bool lucesOk;
  final bool documentosOk;
  final bool limpezaOk;
  final List<String> fotosVeiculoUrls;
  final String? observacoes;
  final DateTime timestamp;

  const ChecklistVeiculo({
    required this.pneusOk,
    required this.freiosOk,
    required this.lucesOk,
    required this.documentosOk,
    required this.limpezaOk,
    this.fotosVeiculoUrls = const [],
    this.observacoes,
    required this.timestamp,
  });

  bool get aprovado => pneusOk && freiosOk && lucesOk && documentosOk && limpezaOk;

  Map<String, dynamic> toJson() => {
        'pneus_ok': pneusOk,
        'freios_ok': freiosOk,
        'luces_ok': lucesOk,
        'documentos_ok': documentosOk,
        'limpeza_ok': limpezaOk,
        'fotos_veiculo_urls': fotosVeiculoUrls,
        'observacoes': observacoes,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChecklistVeiculo.fromJson(Map<String, dynamic> json) => ChecklistVeiculo(
        pneusOk: json['pneus_ok'] ?? false,
        freiosOk: json['freios_ok'] ?? false,
        lucesOk: json['luces_ok'] ?? false,
        documentosOk: json['documentos_ok'] ?? false,
        limpezaOk: json['limpeza_ok'] ?? false,
        fotosVeiculoUrls: (json['fotos_veiculo_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
        observacoes: json['observacoes'],
        timestamp: DateTime.parse(json['timestamp']),
      );

  ChecklistVeiculo copyWith({
    bool? pneusOk,
    bool? freiosOk,
    bool? lucesOk,
    bool? documentosOk,
    bool? limpezaOk,
    List<String>? fotosVeiculoUrls,
    String? observacoes,
    DateTime? timestamp,
  }) =>
      ChecklistVeiculo(
        pneusOk: pneusOk ?? this.pneusOk,
        freiosOk: freiosOk ?? this.freiosOk,
        lucesOk: lucesOk ?? this.lucesOk,
        documentosOk: documentosOk ?? this.documentosOk,
        limpezaOk: limpezaOk ?? this.limpezaOk,
        fotosVeiculoUrls: fotosVeiculoUrls ?? this.fotosVeiculoUrls,
        observacoes: observacoes ?? this.observacoes,
        timestamp: timestamp ?? this.timestamp,
      );
}
