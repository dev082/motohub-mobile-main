import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:hubfrete/models/carga.dart';
import 'package:hubfrete/models/entrega.dart';
import 'package:hubfrete/models/documento_validacao.dart';
import 'package:hubfrete/nav.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/carga_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/services/documento_validacao_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/carga_card.dart';
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

  final TextEditingController _searchController = TextEditingController();
  String? _origemLabel;

  static const double _saldoMock = 0.79;

  bool _isSaldoVisible = true;

  List<Entrega> _entregasAtuais = [];
  List<DocumentoValidacao> _documentosAlerta = [];
  List<Carga> _cargasProximas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDados();
    _loadOrigemFromLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrigemFromLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      final hasPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!hasPermission) return;

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);

      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': position.latitude.toStringAsFixed(6),
        'lon': position.longitude.toStringAsFixed(6),
        'zoom': '10',
        'addressdetails': '1',
      });

      final resp = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'HubFreteDriverApp/1.0 (dreamflow)',
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint(
            'OperacaoDiaScreen: reverse geocode failed status=${resp.statusCode}');
        return;
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) return;
      final address = decoded['address'];
      if (address is! Map) return;

      final city = (address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'])
          ?.toString();
      final state = (address['state_code'] ?? address['state'])?.toString();
      final label = [city, state]
          .where((v) => v != null && v.toString().trim().isNotEmpty)
          .join(', ');
      if (!mounted) return;
      if (label.trim().isEmpty) return;
      setState(() => _origemLabel = label.trim());
    } catch (e) {
      debugPrint(
          'OperacaoDiaScreen: failed to load origin label from location: $e');
    }
  }

  void _goToExplorarWithQuery(String query) {
    context.read<AppProvider>().setExplorarPrefillQuery(query);
    context.go('${AppRoutes.home}?tab=explorar');
  }

  void _openFinanceiro() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Financeiro em breve.')),
    );
  }

  Future<void> _loadDados() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final motoristaId = appProvider.currentMotorista?.id;
      if (motoristaId == null) return;

      final entregas = await _entregaService.getMotoristaEntregas(motoristaId,
          activeOnly: true);
      final docs = await _documentoService.getDocumentosComAlerta(
          motoristaId: motoristaId);

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
        _documentosAlerta = docs
            .where((d) =>
                d.status == StatusDocumento.vence7Dias ||
                d.status == StatusDocumento.vencido)
            .toList();
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

    // Verifica se devemos aplicar o ajuste de "puxar para cima"
    // Só puxamos se NÃO houver alertas de documentos, para colar o input nas cargas.
    final bool shouldPullUp = !_isLoading && _documentosAlerta.isEmpty;

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
                isSaldoVisible: _isSaldoVisible,
                onToggleSaldoVisibility: () =>
                    setState(() => _isSaldoVisible = !_isSaldoVisible),
                onTapCarteira: _openFinanceiro,
                onTapExplorar: () =>
                    context.go('${AppRoutes.home}?tab=explorar'),
                searchController: _searchController,
                origemLabel: _origemLabel,
                onSearchSubmitted: _goToExplorarWithQuery,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // --- CORREÇÃO 1: Agrupamento condicional ---
                  // O SizedBox só aparece se o alerta aparecer.
                  if (!_isLoading && _documentosAlerta.isNotEmpty) ...[
                    _buildAlertasDocumentos(),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // --- CORREÇÃO 2: Ajuste visual ---
                  // Se não tem alertas, puxamos este bloco para cima para cobrir o buraco do Header
                  Transform.translate(
                    offset: Offset(0, shouldPullUp ? -AppSpacing.md : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InicioSectionHeader(
                          title: 'Cargas próximas',
                          trailing: 'Ver mais',
                          onTrailingTap: () =>
                              context.go('${AppRoutes.home}?tab=explorar'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        InicioCargasProximasCard(
                          cargas: _cargasProximas,
                          isLoading: _isLoading,
                          onTapExplorar: () =>
                              context.go('${AppRoutes.home}?tab=explorar'),
                          onTapCarga: (carga) => context
                              .push(AppRoutes.cargaDetailsPath(carga.id)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
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
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    color: theme.colorScheme.onSurface),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Entregas atuais',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('${AppRoutes.home}?tab=entregas'),
                  child: Text(
                    'Ver entregas',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              Column(
                children: [
                  for (final e in _entregasAtuais.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: InicioEntregaCompactTile(
                        entrega: e,
                        onTap: () =>
                            context.go('${AppRoutes.home}?tab=entregas'),
                      ),
                    ),
                ],
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
        const SnackBar(
            content:
                Text('Origem/destino não encontrados para abrir no Maps.')),
      );
      return;
    }

    String formatPoint(
        {required double? lat,
        required double? lng,
        required String fallback}) {
      if (lat != null && lng != null)
        return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
      return fallback;
    }

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
            Icon(Icons.check_circle_outline,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Nenhuma entrega ativa',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Quando você tiver uma entrega ativa, ela aparece aqui.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
        Text('Atalhos',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildAtalhoCard(Icons.directions_car, 'Veículos',
                    () => context.go(AppRoutes.veiculos))),
            const SizedBox(width: 8),
            Expanded(
                child: _buildAtalhoCard(Icons.description, 'Documentos',
                    _showDocumentosBottomSheet)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildAtalhoCard(Icons.insights, 'Relatórios',
                    () => context.go(AppRoutes.relatorios))),
            const SizedBox(width: 8),
            Expanded(
                child: _buildAtalhoCard(Icons.chat_bubble, 'Chat',
                    () => context.go('${AppRoutes.home}?tab=chat'))),
          ],
        ),
      ],
    );
  }

  void _showDocumentosBottomSheet() {
    if (_documentosAlerta.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem alertas de documentos.')));
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
                Text('Documentos em alerta',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
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
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                                isVencido
                                    ? Icons.error_outline
                                    : Icons.warning_amber,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.tipo.displayName,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Nº ${d.numero} • ${isVencido ? 'Vencido' : 'Próximo do vencimento'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant),
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
              Icon(icon,
                  size: 32, color: Theme.of(context).colorScheme.primary),
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
        Text('$label: ',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class InicioTopHeader extends StatelessWidget {
  const InicioTopHeader({
    super.key,
    required this.motoristaNome,
    required this.motoristaFotoUrl,
    required this.saldo,
    required this.isSaldoVisible,
    required this.onToggleSaldoVisibility,
    required this.onTapCarteira,
    required this.onTapExplorar,
    required this.searchController,
    required this.onSearchSubmitted,
    this.origemLabel,
  });

  final String? motoristaNome;
  final String? motoristaFotoUrl;
  final double saldo;
  final bool isSaldoVisible;
  final VoidCallback onToggleSaldoVisibility;
  final VoidCallback onTapCarteira;
  final VoidCallback onTapExplorar;
  final TextEditingController searchController;
  final String? origemLabel;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? DarkModeColors.darkHeader : LightModeColors.lightHeader;
    final onBg =
        isDark ? DarkModeColors.darkOnHeader : LightModeColors.lightOnHeader;
    final muted = isDark
        ? DarkModeColors.darkHeaderMuted
        : LightModeColors.lightHeaderMuted;

    final displayName = (motoristaNome?.trim().isNotEmpty ?? false)
        ? motoristaNome!.trim()
        : 'Motorista';

    return Column(
      children: [
        Container(
          color: bg,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
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
                            Text(displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: onBg, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.verified_outlined,
                                    size: 16, color: muted),
                                const SizedBox(width: 6),
                                Text('Motorista VIP',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _HeaderIconButton(
                          icon: Icons.group_outlined,
                          color: onBg,
                          onPressed: () {}),
                      const SizedBox(width: AppSpacing.xs),
                      _HeaderIconButton(
                          icon: Icons.notifications_none,
                          color: onBg,
                          onPressed: () {}),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isSaldoVisible
                                        ? 'R\$ ${saldo.toStringAsFixed(2)}'
                                        : 'R\$ •••',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                            color: onBg,
                                            fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton(
                                  onPressed: onToggleSaldoVisibility,
                                  icon: Icon(
                                    isSaldoVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: muted,
                                  ),
                                  tooltip: isSaldoVisible
                                      ? 'Ocultar saldo'
                                      : 'Mostrar saldo',
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Saldo',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: muted)),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onTapCarteira,
                        style: TextButton.styleFrom(
                          foregroundColor: onBg,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xl)),
                        ),
                        icon: Icon(Icons.north_east, size: 18, color: onBg),
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
                                child: Text('Localização ativa',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: onBg))),
                            Text('Atualizando',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: muted)),
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
                      label: Text('Explorar cargas',
                          style: TextStyle(
                              color: onBg, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: onBg.withValues(alpha: 0.25)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.xl)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -AppSpacing.md),
          child: Padding(
            padding: AppSpacing.horizontalMd,
            child: InicioSearchCard(
              controller: searchController,
              origemLabel: origemLabel,
              onSubmitted: onSearchSubmitted,
            ),
          ),
        ),
        const SizedBox(height: 0),
      ],
    );
  }
}

class InicioSearchCard extends StatelessWidget {
  const InicioSearchCard({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.origemLabel,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String? origemLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = (origemLabel == null || origemLabel!.trim().isEmpty)
        ? 'sua localização'
        : origemLabel!.trim();
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.14)),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) =>
                    onSubmitted(v.trim().isEmpty ? label : v.trim()),
                decoration: InputDecoration(
                  hintText: 'Origem: $label',
                  hintStyle: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  border: InputBorder.none,
                ),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onSubmitted(controller.text.trim().isEmpty
                  ? label
                  : controller.text.trim()),
              icon:
                  Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              tooltip: 'Pesquisar',
            ),
          ],
        ),
      ),
    );
  }
}

class InicioSectionHeader extends StatelessWidget {
  const InicioSectionHeader(
      {super.key, required this.title, this.trailing, this.onTrailingTap});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800))),
        if (trailing != null)
          TextButton(
            onPressed: onTrailingTap,
            child: Text(trailing!,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class InicioCargasProximasCard extends StatelessWidget {
  const InicioCargasProximasCard({
    super.key,
    required this.cargas,
    required this.isLoading,
    required this.onTapExplorar,
    required this.onTapCarga,
  });

  final List<Carga> cargas;
  final bool isLoading;
  final VoidCallback onTapExplorar;
  final ValueChanged<Carga> onTapCarga;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return SizedBox(
        height: 232,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => const _CargaCardSkeleton(width: 320),
        ),
      );
    }

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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cargas.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final c = cargas[index];
          return SizedBox(
            width: 320,
            child: CargaCard(
              carga: c,
              margin: EdgeInsets.zero,
              onTap: () => onTapCarga(c),
            ),
          );
        },
      ),
    );
  }
}

class _CargaCardSkeleton extends StatefulWidget {
  const _CargaCardSkeleton({this.width});
  final double? width;

  @override
  State<_CargaCardSkeleton> createState() => _CargaCardSkeletonState();
}

class _CargaCardSkeletonState extends State<_CargaCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final highlight =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.20);

    return SizedBox(
      width: widget.width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final color = Color.lerp(base, highlight, _t.value)!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SkelBox(width: 68, height: 20, color: color),
                      const SizedBox(width: AppSpacing.sm),
                      _SkelBox(width: 86, height: 20, color: color),
                      const Spacer(),
                      _SkelBox(width: 72, height: 18, color: color),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SkelBox(width: double.infinity, height: 14, color: color),
                  const SizedBox(height: 8),
                  _SkelBox(width: 220, height: 14, color: color),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                          child: _SkelBox(
                              width: double.infinity,
                              height: 40,
                              color: color)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: _SkelBox(
                              width: double.infinity,
                              height: 40,
                              color: color)),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _SkelBox(width: 86, height: 14, color: color),
                      const SizedBox(width: AppSpacing.md),
                      _SkelBox(width: 108, height: 14, color: color),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SkelBox extends StatelessWidget {
  const _SkelBox(
      {required this.width, required this.height, required this.color});
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

class InicioEntregaCompactTile extends StatelessWidget {
  const InicioEntregaCompactTile(
      {super.key, required this.entrega, required this.onTap});

  final Entrega entrega;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carga = entrega.carga;
    final destino = carga?.destino != null
        ? '${carga!.destino!.cidade}, ${carga.destino!.estado}'
        : 'Destino não informado';
    final title = carga?.descricao ?? 'Entrega';

    final statusColor = switch (entrega.status) {
      StatusEntrega.aguardando => StatusColors.waiting,
      StatusEntrega.saiuParaColeta => StatusColors.collected,
      StatusEntrega.saiuParaEntrega => StatusColors.inTransit,
      StatusEntrega.entregue => StatusColors.delivered,
      StatusEntrega.problema => StatusColors.problem,
      StatusEntrega.cancelada => StatusColors.cancelled,
    };

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.14)),
                ),
                child: Icon(Icons.local_shipping_outlined,
                    color: theme.colorScheme.onSurface),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(destino,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.20)),
                ),
                child: Text(
                  entrega.status.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton(
      {required this.icon, required this.color, required this.onPressed});
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
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
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 1),
        image: hasUrl
            ? DecorationImage(
                image: NetworkImage(url!.trim()), fit: BoxFit.cover)
            : null,
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