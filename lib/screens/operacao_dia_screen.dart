import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/carga.dart';
import 'package:hubfrete/models/entrega.dart';
import 'package:hubfrete/models/documento_validacao.dart';
import 'package:hubfrete/nav.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/carga_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/services/documento_validacao_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tela "Operação do Dia" - Home focada para o motorista
class OperacaoDiaScreen extends StatefulWidget {
  const OperacaoDiaScreen({super.key});

  @override
  State<OperacaoDiaScreen> createState() => _OperacaoDiaScreenState();
}

class _OperacaoDiaScreenState extends State<OperacaoDiaScreen> {
  final _entregaService = EntregaService();
  final _documentoService = DocumentoValidacaoService();
  final _cargaService = CargaService();

  static const double _saldoMock = 0.79;

  List<Entrega> _entregasAtuais = [];
  List<DocumentoValidacao> _documentosAlerta = [];
  List<Carga> _cargasProximas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDados();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDados() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final motoristaId = appProvider.currentMotorista?.id;
      if (motoristaId == null) return;

      final entregas = await _entregaService.getMotoristaEntregas(motoristaId, activeOnly: true);
      final docs = await _documentoService.getDocumentosComAlerta(motoristaId: motoristaId);

      // “Cargas próximas”: por enquanto usamos as cargas disponíveis no backend.
      // No futuro podemos filtrar/ordenar por distância usando a localização atual.
      List<Carga> cargas = [];
      try {
        final motorista = appProvider.currentMotorista;
        if (motorista != null) {
          cargas = await _cargaService.getAvailableCargas(motorista);
        }
      } catch (e) {
        debugPrint('Falha ao carregar cargas disponíveis (Início): $e');
      }

      setState(() {
        _entregasAtuais = entregas.take(8).toList();
        _documentosAlerta = docs.where((d) =>
            d.status == StatusDocumento.vence7Dias || d.status == StatusDocumento.vencido).toList();
        _cargasProximas = cargas.take(6).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Falha ao carregar dados da tela Início: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final motorista = appProvider.currentMotorista;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDados,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: InicioTopHeader(
                motoristaNome: motorista?.nomeCompleto,
                motoristaFotoUrl: motorista?.fotoUrl,
                saldo: _saldoMock,
                onTapExplorar: () => context.go('${AppRoutes.home}?tab=explorar'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (_documentosAlerta.isNotEmpty) _buildAlertasDocumentos(),
                    const SizedBox(height: AppSpacing.lg),
                    InicioSectionHeader(
                      title: 'Cargas próximas',
                      trailing: 'Ver mais',
                      onTrailingTap: () => context.go('${AppRoutes.home}?tab=explorar'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InicioCargasProximasCard(
                      cargas: _cargasProximas,
                      onTapExplorar: () => context.go('${AppRoutes.home}?tab=explorar'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildEntregasAtuais(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildAtalhos(),
                  ],
                ]),
              ),
            ),
          ],
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

  Widget _buildEntregasAtuais() {
    final theme = Theme.of(context);
    final hasEntregas = _entregasAtuais.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: theme.colorScheme.onSurface),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Entregas atuais',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('${AppRoutes.home}?tab=entregas'),
                  child: Text(
                    'Ver entregas',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!hasEntregas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Você não tem entregas em andamento no momento.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: 168,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _entregasAtuais.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final e = _entregasAtuais[index];
                    return InicioEntregaCompactTile(
                      entrega: e,
                      onTap: () => context.go('${AppRoutes.home}?tab=entregas'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMapsParaEntrega(Entrega entrega) async {
    final carga = entrega.carga;
    final origem = carga?.origem;
    final destino = carga?.destino;

    if (origem == null || destino == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origem/destino não encontrados para abrir no Maps.')),
      );
      return;
    }

    String formatPoint({required double? lat, required double? lng, required String fallback}) {
      if (lat != null && lng != null) return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
      return fallback;
    }

    // Objetivo: usuário segue rota com 2 pernas:
    // 1) localização atual -> origem
    // 2) origem -> destino
    // No Google Maps isso funciona bem com: waypoints=origem e destination=destino.
    final origemText = formatPoint(
      lat: origem.latitude,
      lng: origem.longitude,
      fallback: origem.enderecoCompleto,
    );
    final destinoText = formatPoint(
      lat: destino.latitude,
      lng: destino.longitude,
      fallback: destino.enderecoCompleto,
    );

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destinoText,
      'waypoints': origemText,
      'travelmode': 'driving',
    });

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        debugPrint('OperacaoDiaScreen: launchUrl returned false for $uri');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o Maps.')),
        );
      }
    } catch (e) {
      debugPrint('OperacaoDiaScreen: failed to open maps: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao abrir o Maps.')),
      );
    }
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
              'Quando você tiver uma entrega ativa, ela aparece aqui.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('${AppRoutes.home}?tab=explorar'),
              icon: const Icon(Icons.search),
              label: const Text('Explorar'),
            )
          ],
        ),
      ),
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

  // _toggleTracking removido.
}

class InicioTopHeader extends StatelessWidget {
  const InicioTopHeader({
    super.key,
    required this.motoristaNome,
    required this.motoristaFotoUrl,
    required this.saldo,
    required this.onTapExplorar,
  });

  final String? motoristaNome;
  final String? motoristaFotoUrl;
  final double saldo;
  final VoidCallback onTapExplorar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? DarkModeColors.darkHeader : LightModeColors.lightHeader;
    final onBg = isDark ? DarkModeColors.darkOnHeader : LightModeColors.lightOnHeader;
    final muted = isDark ? DarkModeColors.darkHeaderMuted : LightModeColors.lightHeaderMuted;

    final displayName = (motoristaNome?.trim().isNotEmpty ?? false) ? motoristaNome!.trim() : 'Motorista';

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          Container(
            height: 232,
            color: bg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _DriverAvatar(url: motoristaFotoUrl, size: 42),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: theme.textTheme.titleMedium?.copyWith(color: onBg, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.verified_outlined, size: 16, color: muted),
                                  const SizedBox(width: 6),
                                  Text('Motorista VIP', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _HeaderIconButton(icon: Icons.group_outlined, color: onBg, onPressed: () {}),
                        const SizedBox(width: AppSpacing.xs),
                        _HeaderIconButton(icon: Icons.notifications_none, color: onBg, onPressed: () {}),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('R\$ ${saldo.toStringAsFixed(2)}', style: theme.textTheme.headlineSmall?.copyWith(color: onBg, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text('Saldo', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: onBg,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                          ),
                          icon: Icon(Icons.account_balance_wallet_outlined, size: 18, color: onBg),
                          label: const Text('Minha carteira'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('Localização ativa', style: theme.textTheme.bodyMedium?.copyWith(color: onBg)),
                              ),
                              Text('Atualizando', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: onTapExplorar,
                        icon: Icon(Icons.explore_outlined, size: 18, color: onBg),
                        label: Text('Explorar cargas', style: TextStyle(color: onBg, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: onBg.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 0,
            child: InicioSearchCard(
              onTap: onTapExplorar,
            ),
          ),
        ],
      ),
    );
  }
}

class InicioSearchCard extends StatelessWidget {
  const InicioSearchCard({super.key, required this.onTap, this.origemLabel});
  final VoidCallback onTap;
  final String? origemLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = (origemLabel == null || origemLabel!.trim().isEmpty) ? 'sua localização' : origemLabel!.trim();
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Origem: $label',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class InicioSectionHeader extends StatelessWidget {
  const InicioSectionHeader({super.key, required this.title, this.trailing, this.onTrailingTap});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        if (trailing != null)
          TextButton(
            onPressed: onTrailingTap,
            child: Text(trailing!, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class InicioCargasProximasCard extends StatelessWidget {
  const InicioCargasProximasCard({
    super.key,
    required this.cargas,
    required this.onTapExplorar,
  });

  final List<Carga> cargas;
  final VoidCallback onTapExplorar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cargas.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Sem cargas para mostrar agora. Tente explorar.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: onTapExplorar,
                child: const Text('Explorar'),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: cargas.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final c = cargas[index];
          final origem = c.origem != null ? '${c.origem!.cidade}, ${c.origem!.estado}' : 'Origem';
          final destino = c.destino != null ? '${c.destino!.cidade}, ${c.destino!.estado}' : 'Destino';

          return SizedBox(
            width: 260,
            child: Card(
              child: InkWell(
                onTap: onTapExplorar,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${origem.split(',').first} → ${destino.split(',').first}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.descricao,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.near_me_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              origem,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class InicioEntregaCompactTile extends StatelessWidget {
  const InicioEntregaCompactTile({super.key, required this.entrega, required this.onTap});

  final Entrega entrega;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carga = entrega.carga;
    final destino = carga?.destino != null ? '${carga!.destino!.cidade}, ${carga.destino!.estado}' : 'Destino não informado';
    final title = carga?.descricao ?? 'Entrega';

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.14)),
                ),
                child: Icon(Icons.local_shipping_outlined, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(destino, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                entrega.status.displayName,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.color, required this.onPressed});
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = url != null && url!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size),
        color: theme.colorScheme.surface.withValues(alpha: 0.12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 1),
        image: hasUrl ? DecorationImage(image: NetworkImage(url!.trim()), fit: BoxFit.cover) : null,
      ),
      child: !hasUrl
          ? Center(
              child: Icon(
                Icons.person,
                size: size * 0.62,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}
