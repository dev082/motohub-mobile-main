import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/models/documento_validacao.dart';
import 'package:motohub/nav.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/services/documento_validacao_service.dart';
import 'package:motohub/services/location_tracking_service.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/app_drawer.dart';
import 'package:provider/provider.dart';

/// Tela "Operação do Dia" - Home focada para o motorista
class OperacaoDiaScreen extends StatefulWidget {
  const OperacaoDiaScreen({super.key});

  @override
  State<OperacaoDiaScreen> createState() => _OperacaoDiaScreenState();
}

class _OperacaoDiaScreenState extends State<OperacaoDiaScreen> {
  final _entregaService = EntregaService();
  final _documentoService = DocumentoValidacaoService();

  Entrega? _entregaAtual;
  List<Entrega> _proximasEntregas = [];
  List<DocumentoValidacao> _documentosAlerta = [];
  bool _isLoading = true;
  bool _isTrackingAtivo = false;

  @override
  void initState() {
    super.initState();
    _loadDados();
    _checkTrackingStatus();
  }

  Future<void> _loadDados() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final motoristaId = appProvider.currentMotorista?.id;
      if (motoristaId == null) return;

      final entregas = await _entregaService.getMotoristaEntregas(motoristaId, activeOnly: true);
      final docs = await _documentoService.getDocumentosComAlerta(motoristaId: motoristaId);

      setState(() {
        if (entregas.isNotEmpty) {
          _entregaAtual = entregas.first;
          _proximasEntregas = entregas.skip(1).take(3).toList();
        }
        _documentosAlerta = docs.where((d) =>
            d.status == StatusDocumento.vence7Dias || d.status == StatusDocumento.vencido).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkTrackingStatus() async {
    final isActive = LocationTrackingService.instance.isTracking;
    setState(() => _isTrackingAtivo = isActive);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = context.watch<AppProvider>();
    final motorista = appProvider.currentMotorista;

    return Scaffold(
      drawer: AppDrawer(activeRoute: GoRouterState.of(context).matchedLocation),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operação do Dia', style: theme.textTheme.titleLarge),
            if (motorista != null)
                Text(motorista.nomeCompleto, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
              icon: Icon(
                _isTrackingAtivo ? Icons.gps_fixed : Icons.gps_off,
                color: _isTrackingAtivo ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            onPressed: _toggleTracking,
            tooltip: _isTrackingAtivo ? 'Sim, está funcionando.' : 'Não, não está funcionando.',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDados,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_documentosAlerta.isNotEmpty) _buildAlertasDocumentos(),
                    const SizedBox(height: 16),
                    if (_entregaAtual != null) ...[
                      _buildEntregaAtual(),
                      const SizedBox(height: 24),
                    ] else
                      _buildSemEntregasAtivas(),
                    if (_proximasEntregas.isNotEmpty) ...[
                      _buildProximasEntregas(),
                      const SizedBox(height: 24),
                    ],
                    _buildAtalhos(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAlertasDocumentos() {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atenção: Documentos',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    '${_documentosAlerta.length} documento(s) ${_documentosAlerta.any((d) => d.status == StatusDocumento.vencido) ? 'vencido(s)' : 'próximo(s) do vencimento'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                _showDocumentosBottomSheet();
              },
              child: const Text('Ver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntregaAtual() {
    final entrega = _entregaAtual!;
    final carga = entrega.carga;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Entrega Atual', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Chip(
                  label: Text(entrega.status.displayName, style: Theme.of(context).textTheme.labelSmall),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const Divider(height: 24),
            if (carga != null) ...[
              _buildInfoRow(Icons.inventory, 'Carga', carga.descricao),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on, 'Destino', carga.destino?.cidade ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.scale, 'Peso', '${entrega.pesoAlocadoKg?.toStringAsFixed(0) ?? '0'} kg'),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.entregaMapaPath(entrega.id)),
                    icon: const Icon(Icons.map),
                    label: const Text('Ver Rota'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.chatPath(entrega.id)),
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemEntregasAtivas() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Nenhuma entrega ativa', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Você está livre para aceitar novas cargas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navegar para Explorar
              },
              icon: const Icon(Icons.search),
              label: const Text('Explorar Cargas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProximasEntregas() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Próximas Entregas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._proximasEntregas.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.local_shipping_outlined, color: theme.colorScheme.primary),
                title: Text(e.carga?.descricao ?? 'Carga', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(e.status.displayName),
                trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                onTap: () => context.push(AppRoutes.entregaMapaPath(e.id)),
                tileColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
      ],
    );
  }

  Widget _buildAtalhos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Atalhos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildAtalhoCard(Icons.directions_car, 'Veículos', () => context.go(AppRoutes.veiculos))),
            const SizedBox(width: 8),
            Expanded(child: _buildAtalhoCard(Icons.description, 'Documentos', _showDocumentosBottomSheet)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildAtalhoCard(Icons.insights, 'Relatórios', () => context.go(AppRoutes.relatorios))),
            const SizedBox(width: 8),
            Expanded(child: _buildAtalhoCard(Icons.chat_bubble, 'Chat', () => context.go('${AppRoutes.home}?tab=chat'))),
          ],
        ),
      ],
    );
  }

  void _showDocumentosBottomSheet() {
    if (_documentosAlerta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem alertas de documentos.')));
      return;
    }

    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documentos em alerta', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: ListView.separated(
                    itemCount: _documentosAlerta.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final d = _documentosAlerta[index];
                      final isVencido = d.status == StatusDocumento.vencido;
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(isVencido ? Icons.error_outline : Icons.warning_amber, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.tipo.displayName,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Nº ${d.numero} • ${isVencido ? 'Vencido' : 'Próximo do vencimento'}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: context.pop,
                    icon: const Icon(Icons.close),
                    label: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAtalhoCard(IconData icon, String label, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Future<void> _toggleTracking() async {
    final motorista = context.read<AppProvider>().currentMotorista;
    if (motorista == null) return;
    
    if (_isTrackingAtivo) {
      await LocationTrackingService.instance.stopTracking();
    } else {
      if (_entregaAtual != null) {
        final ok = await LocationTrackingService.instance.startTracking(_entregaAtual!.id, motorista.id);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permita a localização para ativar o rastreador (Configurações / navegador).')),
          );
        }
      }
    }
    await _checkTrackingStatus();
  }
}
