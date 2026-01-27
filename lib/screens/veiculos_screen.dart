import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/models/carroceria.dart';
import 'package:motohub/models/motorista.dart';
import 'package:motohub/models/veiculo.dart';
import 'package:motohub/nav.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/services/carroceria_service.dart';
import 'package:motohub/services/veiculo_service.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/app_drawer.dart';
import 'package:motohub/widgets/veiculo_card.dart';
import 'package:motohub/widgets/carroceria_card.dart';
import 'package:motohub/widgets/pull_to_refresh.dart';
import 'package:provider/provider.dart';

/// Screen for managing vehicles and trailers
class VeiculosScreen extends StatefulWidget {
  const VeiculosScreen({super.key});

  @override
  State<VeiculosScreen> createState() => _VeiculosScreenState();
}

class _VeiculosScreenState extends State<VeiculosScreen> {
  final VeiculoService _veiculoService = VeiculoService();
  final CarroceriaService _carroceriaService = CarroceriaService();

  bool _showVeiculos = true;
  bool _isLoading = true;
  List<Veiculo> _veiculos = [];
  List<Carroceria> _carrocerias = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final motorista = context.read<AppProvider>().currentMotorista;
    if (motorista == null) return;

    setState(() => _isLoading = true);

    try {
      final veiculos = await _veiculoService.getVeiculosByMotorista(motorista.id);
      final carrocerias = await _carroceriaService.getCarroceriasByMotorista(motorista.id);

      if (mounted) {
        setState(() {
          _veiculos = veiculos;
          _carrocerias = carrocerias;
        });
      }
    } catch (e) {
      debugPrint('Load vehicles/trailers error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVeiculo(Veiculo veiculo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Veículo'),
        content: Text('Deseja remover o veículo ${veiculo.placa}?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _veiculoService.deleteVeiculo(veiculo.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veículo removido com sucesso')),
      );
      _loadData();
    }
  }

  Future<void> _deleteCarroceria(Carroceria carroceria) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Carroceria'),
        content: Text('Deseja remover a carroceria ${carroceria.placa}?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _carroceriaService.deleteCarroceria(carroceria.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carroceria removida com sucesso')),
      );
      _loadData();
    }
  }

  Future<void> _navigateToVeiculoForm([Veiculo? veiculo]) async {
    final result = await context.push<bool>(AppRoutes.veiculoForm, extra: veiculo);
    if (result == true) await _loadData();
  }

  Future<void> _navigateToCarroceriaForm([Carroceria? carroceria]) async {
    final result = await context.push<bool>(AppRoutes.carroceriaForm, extra: carroceria);
    if (result == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final motorista = context.watch<AppProvider>().currentMotorista;
    if (motorista == null) {
      return const Scaffold(
        body: Center(child: Text('Motorista não encontrado')),
      );
    }

    final isFrota = motorista.tipoCadastro == TipoCadastroMotorista.frota;

    return Scaffold(
      drawer: AppDrawer(activeRoute: GoRouterState.of(context).matchedLocation),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: const Text('Veículos e Carrocerias'),
        actions: [
          if (context.canPop())
            IconButton(
              onPressed: context.pop,
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Veículos'), icon: Icon(Icons.local_shipping)),
                      ButtonSegment(value: false, label: Text('Carrocerias'), icon: Icon(Icons.view_carousel)),
                    ],
                    selected: {_showVeiculos},
                    onSelectionChanged: (selection) {
                      setState(() => _showVeiculos = selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (isFrota)
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingSm,
                    color: Colors.orange.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Motoristas de frota podem apenas visualizar. Para alterações, entre em contato com a transportadora.',
                            style: context.textStyles.bodySmall?.copyWith(color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: PullToRefresh(
                    onRefresh: _loadData,
                    child: _showVeiculos ? _buildVeiculosList(isFrota) : _buildCarroceriasList(isFrota),
                  ),
                ),
              ],
            ),
      floatingActionButton: isFrota
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showVeiculos ? _navigateToVeiculoForm() : _navigateToCarroceriaForm(),
              icon: const Icon(Icons.add),
              label: Text(_showVeiculos ? 'Adicionar Veículo' : 'Adicionar Carroceria'),
            ),
    );
  }

  Widget _buildVeiculosList(bool isFrota) {
    if (_veiculos.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.paddingMd,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Nenhum veículo cadastrado', style: context.textStyles.titleMedium, textAlign: TextAlign.center),
                  if (!isFrota) ...[
                    const SizedBox(height: 8),
                    Text('Toque no botão abaixo para adicionar', style: context.textStyles.bodySmall, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.paddingMd,
      itemCount: _veiculos.length,
      itemBuilder: (context, index) {
        final veiculo = _veiculos[index];
        return VeiculoCard(
          veiculo: veiculo,
          onTap: isFrota ? null : () => _navigateToVeiculoForm(veiculo),
          onDelete: isFrota ? null : () => _deleteVeiculo(veiculo),
        );
      },
    );
  }

  Widget _buildCarroceriasList(bool isFrota) {
    if (_carrocerias.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.paddingMd,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.view_carousel_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Nenhuma carroceria cadastrada', style: context.textStyles.titleMedium, textAlign: TextAlign.center),
                  if (!isFrota) ...[
                    const SizedBox(height: 8),
                    Text('Toque no botão abaixo para adicionar', style: context.textStyles.bodySmall, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.paddingMd,
      itemCount: _carrocerias.length,
      itemBuilder: (context, index) {
        final carroceria = _carrocerias[index];
        return CarroceriaCard(
          carroceria: carroceria,
          onTap: isFrota ? null : () => _navigateToCarroceriaForm(carroceria),
          onDelete: isFrota ? null : () => _deleteCarroceria(carroceria),
        );
      },
    );
  }
}
