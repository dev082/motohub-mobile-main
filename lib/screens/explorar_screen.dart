import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/carga.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/carga_service.dart';
import 'package:hubfrete/nav.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/app_drawer.dart';
import 'package:hubfrete/widgets/carga_card.dart';
import 'package:hubfrete/widgets/pull_to_refresh.dart';
import 'package:hubfrete/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// Explorar screen - shows available cargas for the motorista
class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  final CargaService _cargaService = CargaService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Carga> _cargas = [];
  List<Carga> _filteredCargas = [];
  bool _isLoading = true;
  TipoCarga? _selectedTipo;

  @override
  void initState() {
    super.initState();
    _loadCargas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCargas() async {
    setState(() => _isLoading = true);
    try {
      final motorista = context.read<AppProvider>().currentMotorista;
      if (motorista == null) {
        debugPrint('Cannot load cargas: motorista is null');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('ExplorarScreen: Loading cargas...');
      final cargas = await _cargaService.getAvailableCargas(motorista);
      debugPrint('ExplorarScreen: Received ${cargas.length} cargas');
      
      setState(() {
        _cargas = cargas;
        _filteredCargas = cargas;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ExplorarScreen: Error loading cargas: $e');
      setState(() => _isLoading = false);
      if (mounted) AppErrorReporter.report(context, e, operation: 'carregar cargas');
    }
  }

  void _filterCargas() {
    setState(() {
      _filteredCargas = _cargas.where((carga) {
        final searchText = _searchController.text.toLowerCase();
        final matchesSearch = searchText.isEmpty ||
            carga.codigo.toLowerCase().contains(searchText) ||
            carga.descricao.toLowerCase().contains(searchText) ||
            (carga.origem?.cidade.toLowerCase().contains(searchText) ?? false) ||
            (carga.destino?.cidade.toLowerCase().contains(searchText) ?? false);

        final matchesTipo = _selectedTipo == null || carga.tipo == _selectedTipo;

        return matchesSearch && matchesTipo;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Explorar Cargas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          if (context.canPop())
            IconButton(onPressed: context.pop, icon: const Icon(Icons.close), tooltip: 'Fechar'),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: AppSpacing.horizontalMd + AppSpacing.verticalSm,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filterCargas(),
              decoration: InputDecoration(
                hintText: 'Buscar por código, descrição ou cidade...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),

          // Filter chips
          if (_selectedTipo != null)
            Padding(
              padding: AppSpacing.horizontalMd,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  FilterChip(
                    label: Text(_selectedTipo!.displayName),
                    selected: true,
                    onSelected: (_) {
                      setState(() => _selectedTipo = null);
                      _filterCargas();
                    },
                  ),
                ],
              ),
            ),

          // Cargas list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PullToRefresh(
                    onRefresh: _loadCargas,
                    child: _filteredCargas.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppSpacing.paddingMd,
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.55,
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppSpacing.paddingMd,
                            itemCount: _filteredCargas.length,
                            itemBuilder: (context, index) {
                              final carga = _filteredCargas[index];
                              return CargaCard(
                                carga: carga,
                                onTap: () => context.push(AppRoutes.cargaDetailsPath(carga.id)),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final motorista = context.read<AppProvider>().currentMotorista;
    final isFrota = motorista?.isFrota ?? false;
    
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhuma carga disponível',
              style: context.textStyles.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isFrota
                  ? 'Explorar cargas não está disponível para motoristas de frota'
                  : 'Tente ajustar os filtros de busca',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isFrota && motorista != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Motorista de Frota',
                      style: context.textStyles.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Por regra da operação, motoristas de frota não visualizam cargas no Explorar.',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Motoristas autônomos veem todas as cargas disponíveis',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por tipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<TipoCarga?>(
              title: const Text('Todos'),
              value: null,
              groupValue: _selectedTipo,
              onChanged: (value) {
                setState(() => _selectedTipo = value);
                _filterCargas();
                context.pop();
              },
            ),
            ...TipoCarga.values.map((tipo) {
              return RadioListTile<TipoCarga?>(
                title: Text(tipo.displayName),
                value: tipo,
                groupValue: _selectedTipo,
                onChanged: (value) {
                  setState(() => _selectedTipo = value);
                  _filterCargas();
                  context.pop();
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: context.pop,
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
