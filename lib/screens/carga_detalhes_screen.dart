import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:motohub/models/carga.dart';
import 'package:motohub/models/carroceria.dart';
import 'package:motohub/models/veiculo.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/services/carga_service.dart';
import 'package:motohub/services/carroceria_service.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/services/veiculo_service.dart';
import 'package:motohub/nav.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/entrega_route_preview.dart';
import 'package:provider/provider.dart';

/// Tela de detalhes da Carga.
///
/// Mostra informações básicas + preview da rota (origem -> destino).
class CargaDetalhesScreen extends StatefulWidget {
  final String cargaId;
  const CargaDetalhesScreen({super.key, required this.cargaId});

  @override
  State<CargaDetalhesScreen> createState() => _CargaDetalhesScreenState();
}

class _CargaDetalhesScreenState extends State<CargaDetalhesScreen> {
  final CargaService _service = CargaService();
  final EntregaService _entregaService = EntregaService();
  final VeiculoService _veiculoService = VeiculoService();
  final CarroceriaService _carroceriaService = CarroceriaService();
  late Future<Carga?> _future;

  bool _accepting = false;
  String? _selectedVeiculoId;
  String? _selectedCarroceriaId;
  final TextEditingController _pesoController = TextEditingController();
  List<Veiculo> _veiculos = const [];
  List<Carroceria> _carrocerias = const [];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadAssets();
  }

  @override
  void dispose() {
    _pesoController.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _future = _load());

  Future<Carga?> _load() async {
    try {
      debugPrint('CargaDetalhesScreen: loading cargaId=${widget.cargaId}');
      return _service.getCargaById(widget.cargaId);
    } catch (e) {
      debugPrint('CargaDetalhesScreen: failed to load carga: $e');
      return null;
    }
  }

  Future<void> _loadAssets() async {
    final motorista = context.read<AppProvider>().currentMotorista;
    if (motorista == null) return;
    if (motorista.isFrota) return;

    try {
      final results = await Future.wait([
        _veiculoService.getVeiculosByMotorista(motorista.id),
        _carroceriaService.getCarroceriasByMotorista(motorista.id),
      ]);
      if (!mounted) return;
      setState(() {
        _veiculos = results[0] as List<Veiculo>;
        _carrocerias = results[1] as List<Carroceria>;

        // Preselect first active vehicle to reduce friction.
        if (_selectedVeiculoId == null || _selectedVeiculoId!.isEmpty) {
          final firstActive = _veiculos.where((v) => v.ativo).toList();
          _selectedVeiculoId = (firstActive.isNotEmpty ? firstActive.first.id : (_veiculos.isNotEmpty ? _veiculos.first.id : null));
        }

        // Default optional carroceria selection to "none".
        _selectedCarroceriaId ??= '';
      });
    } catch (e) {
      debugPrint('CargaDetalhesScreen: failed to load veiculos/carrocerias: $e');
    }
  }

  double? _parsePeso() {
    final raw = _pesoController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _onAccept(Carga carga) async {
    final motorista = context.read<AppProvider>().currentMotorista;
    if (motorista == null) return;

    if (motorista.isFrota) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Motoristas de frota não podem aceitar cargas.')));
      return;
    }

    final veiculoId = _selectedVeiculoId;
    if (veiculoId == null || veiculoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um veículo para aceitar a carga.')));
      return;
    }

    final peso = _parsePeso();
    if (peso == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe quantos kg você quer levar.')));
      return;
    }

    Veiculo? veiculo;
    for (final v in _veiculos) {
      if (v.id == veiculoId) {
        veiculo = v;
        break;
      }
    }
    final capacidade = veiculo?.capacidadeKg;
    if (capacidade != null && peso > capacidade) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Peso maior que a capacidade do veículo (${capacidade.toStringAsFixed(0)} kg).')));
      return;
    }

    final pesoDisponivelCarga = (carga.pesoDisponivelKg ?? carga.pesoKg);
    if (peso > pesoDisponivelCarga) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Peso maior que o disponível na carga (${pesoDisponivelCarga.toStringAsFixed(0)} kg).')));
      return;
    }

    if (carga.permiteFracionado == false && peso != carga.pesoKg) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta carga não permite fracionamento.')));
      return;
    }

    setState(() => _accepting = true);
    try {
      final entrega = await _entregaService.acceptCargaAutomatico(
        cargaId: carga.id,
        veiculoId: veiculoId,
        carroceriaId: (_selectedCarroceriaId == null || _selectedCarroceriaId!.isEmpty) ? null : _selectedCarroceriaId,
        pesoKg: peso,
      );

      if (!mounted) return;
      if (entrega == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível aceitar a carga agora.')));
        return;
      }

      // Navigate to entrega details.
      context.go(AppRoutes.entregaDetailsPath(entrega.id));
    } catch (e) {
      debugPrint('CargaDetalhesScreen: accept failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao aceitar carga: $e')));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final motorista = context.watch<AppProvider>().currentMotorista;

    // Regra de negócio: frota não vê cargas no explorar/detalhe.
    if (motorista?.isFrota ?? false) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: context.pop), title: const Text('Carga')),
        body: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 56, color: cs.outline),
                const SizedBox(height: AppSpacing.md),
                Text('Acesso restrito', style: context.textStyles.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Motoristas de frota não visualizam cargas no Explorar.',
                  style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: context.pop),
        title: const Text('Detalhes da Carga'),
      ),
      body: FutureBuilder<Carga?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final carga = snapshot.data;
          if (carga == null) {
            return Center(
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 56, color: cs.outline),
                    const SizedBox(height: AppSpacing.md),
                    Text('Carga não encontrada', style: context.textStyles.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Não foi possível carregar esta carga agora.',
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: Icon(Icons.refresh, color: cs.onPrimary),
                      label: Text('Tentar novamente', style: TextStyle(color: cs.onPrimary)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: AppSpacing.paddingMd,
            children: [
              _Header(carga: carga),
              const SizedBox(height: AppSpacing.md),

              // Preview de rota
              EntregaRoutePreview(origem: carga.origem, destino: carga.destino, height: 200),
              const SizedBox(height: AppSpacing.md),

              _InfoCard(carga: carga),
              const SizedBox(height: AppSpacing.md),
              _EnderecoCard(title: 'Origem', icon: Icons.circle, color: cs.primary, endereco: carga.origem),
              const SizedBox(height: AppSpacing.md),
              _EnderecoCard(title: 'Destino', icon: Icons.location_on, color: cs.error, endereco: carga.destino),
              const SizedBox(height: AppSpacing.lg),

              _AceiteCard(
                carga: carga,
                veiculos: _veiculos,
                carrocerias: _carrocerias,
                selectedVeiculoId: _selectedVeiculoId,
                selectedCarroceriaId: _selectedCarroceriaId,
                pesoController: _pesoController,
                accepting: _accepting,
                onVeiculoChanged: (id) => setState(() => _selectedVeiculoId = id),
                onCarroceriaChanged: (id) => setState(() => _selectedCarroceriaId = id),
                onAccept: () => _onAccept(carga),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AceiteCard extends StatelessWidget {
  final Carga carga;
  final List<Veiculo> veiculos;
  final List<Carroceria> carrocerias;
  final String? selectedVeiculoId;
  final String? selectedCarroceriaId;
  final TextEditingController pesoController;
  final bool accepting;
  final ValueChanged<String?> onVeiculoChanged;
  final ValueChanged<String?> onCarroceriaChanged;
  final VoidCallback onAccept;

  const _AceiteCard({
    required this.carga,
    required this.veiculos,
    required this.carrocerias,
    required this.selectedVeiculoId,
    required this.selectedCarroceriaId,
    required this.pesoController,
    required this.accepting,
    required this.onVeiculoChanged,
    required this.onCarroceriaChanged,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pesoDisponivel = (carga.pesoDisponivelKg ?? carga.pesoKg);
    final allowsAccept = carga.status == StatusCarga.publicada || carga.status == StatusCarga.parcialmenteAlocada;

    final activeVehicles = veiculos.where((v) => v.ativo).toList(growable: false);
    final activeCarrocerias = carrocerias.where((c) => c.ativo).toList(growable: false);

    if (!allowsAccept) {
      return Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Esta carga não está disponível para aceite agora (status: ${carga.status.value}).',
                style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aceitar carga', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Disponível: ${pesoDisponivel.toStringAsFixed(0)} kg',
            style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),

          DropdownButtonFormField<String>(
            value: activeVehicles.isEmpty ? null : selectedVeiculoId,
            items: [
              for (final v in activeVehicles)
                DropdownMenuItem(
                  value: v.id,
                  child: Text('${v.placa} • ${v.tipo.label}${v.capacidadeKg != null ? ' • ${v.capacidadeKg!.toStringAsFixed(0)}kg' : ''}'),
                ),
            ],
            onChanged: (accepting || activeVehicles.isEmpty) ? null : onVeiculoChanged,
            decoration: const InputDecoration(labelText: 'Veículo'),
          ),
          const SizedBox(height: AppSpacing.md),

          DropdownButtonFormField<String>(
            value: selectedCarroceriaId,
            items: [
              const DropdownMenuItem(value: '', child: Text('Sem carroceria')),
              for (final c in activeCarrocerias)
                DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.placa} • ${c.tipo}${c.capacidadeKg != null ? ' • ${c.capacidadeKg!.toStringAsFixed(0)}kg' : ''}'),
                ),
            ],
            onChanged: accepting ? null : onCarroceriaChanged,
            decoration: const InputDecoration(labelText: 'Carroceria (opcional)'),
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: pesoController,
            enabled: !accepting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantos kg você quer levar?',
              hintText: carga.permiteFracionado == false ? carga.pesoKg.toStringAsFixed(0) : pesoDisponivel.toStringAsFixed(0),
              prefixIcon: Icon(Icons.scale, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: accepting ? null : onAccept,
              icon: accepting
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : Icon(Icons.check_circle, color: cs.onPrimary),
              label: Text(
                accepting ? 'Aceitando…' : 'Aceitar agora',
                style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          if (activeVehicles.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Você precisa cadastrar um veículo antes de aceitar.',
              style: context.textStyles.bodySmall?.copyWith(color: cs.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Carga carga;
  const _Header({required this.carga});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(text: carga.codigo, background: cs.primaryContainer, foreground: cs.onPrimaryContainer),
                    _Pill(text: carga.tipo.displayName, background: cs.surface, foreground: cs.onSurfaceVariant),
                    _Pill(text: carga.status.value.replaceAll('_', ' '), background: cs.secondaryContainer, foreground: cs.onSecondaryContainer),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(carga.descricao, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (carga.valorFreteTonelada != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Frete', style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  money.format(carga.valorFreteTonelada),
                  style: context.textStyles.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const _Pill({required this.text, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: context.textStyles.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Carga carga;
  const _InfoCard({required this.carga});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('dd/MM/yyyy');

    String? windowText(DateTime? start, DateTime? end) {
      if (start == null && end == null) return null;
      if (start != null && end != null) return '${date.format(start)} • ${date.format(end)}';
      return date.format(start ?? end!);
    }

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informações', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(icon: Icons.scale, label: 'Peso', value: '${carga.pesoKg.toStringAsFixed(0)} kg'),
          if (carga.volumeM3 != null) _InfoRow(icon: Icons.view_in_ar, label: 'Volume', value: '${carga.volumeM3!.toStringAsFixed(2)} m³'),
          if (carga.dataColetaDe != null || carga.dataColetaAte != null)
            _InfoRow(icon: Icons.calendar_today, label: 'Janela de coleta', value: windowText(carga.dataColetaDe, carga.dataColetaAte) ?? '-'),
          if (carga.dataEntregaLimite != null)
            _InfoRow(icon: Icons.event_available, label: 'Entrega limite', value: date.format(carga.dataEntregaLimite!)),
          if (carga.permiteFracionado == false)
            _InfoRow(icon: Icons.block, label: 'Fracionado', value: 'Não permite'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (carga.cargaPerigosa) _Tag(icon: Icons.warning, text: 'Perigosa'),
              if (carga.requerRefrigeracao) _Tag(icon: Icons.ac_unit, text: 'Refrigerada'),
              if (carga.cargaFragil) _Tag(icon: Icons.egg_outlined, text: 'Frágil'),
              if (carga.cargaViva) _Tag(icon: Icons.pets, text: 'Viva'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          Text(value, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(text, style: context.textStyles.labelMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EnderecoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final EnderecoCarga? endereco;
  const _EnderecoCard({required this.title, required this.icon, required this.color, required this.endereco});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = endereco;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (e == null)
            Text('Não informado', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
          else ...[
            Text('${e.cidade} - ${e.estado}', style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(e.enderecoCompleto, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            if (e.cep.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('CEP: ${e.cep}', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
            if ((e.contatoNome?.isNotEmpty ?? false) || (e.contatoTelefone?.isNotEmpty ?? false)) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [e.contatoNome, e.contatoTelefone].where((v) => v != null && v!.isNotEmpty).map((v) => v!).join(' • '),
                      style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ]
        ],
      ),
    );
  }
}
