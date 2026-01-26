import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:motohub/models/carga.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/services/route_service.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/entrega_details_sheet.dart';

/// Full-screen, interactive route map for an entrega.
///
/// Features:
/// - Pinch-zoom / drag / rotate (flutter_map)
/// - Route polyline + origin/destination markers
/// - Draggable bottom panel with route metrics (km, time, avg speed, liters)
class EntregaRouteMapScreen extends StatefulWidget {
  final String entregaId;

  /// Used to estimate fuel consumption in liters.
  /// Example: 25 means 25 km/L.
  final double consumoKmPorLitro;

  const EntregaRouteMapScreen({super.key, required this.entregaId, this.consumoKmPorLitro = 25});

  @override
  State<EntregaRouteMapScreen> createState() => _EntregaRouteMapScreenState();
}

class _EntregaRouteMapScreenState extends State<EntregaRouteMapScreen> {
  final MapController _mapController = MapController();
  final EntregaService _entregaService = EntregaService();
  Entrega? _entrega;
  RouteResult? _route;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entrega = await _entregaService.getEntregaById(widget.entregaId);
      if (!mounted) return;
      if (entrega == null) {
        setState(() {
          _entrega = null;
          _route = null;
          _error = 'Entrega não encontrada';
          _loading = false;
        });
        return;
      }

      final origem = entrega.carga?.origem;
      final destino = entrega.carga?.destino;
      if (!_hasCoords(origem) || !_hasCoords(destino)) {
        setState(() {
          _entrega = entrega;
          _route = null;
          _loading = false;
        });
        return;
      }

      final origin = LatLng(origem!.latitude!, origem.longitude!);
      final dest = LatLng(destino!.latitude!, destino.longitude!);
      final cached = RouteService.instance.getCached(origin, dest);
      final route = cached ?? await RouteService.instance.getDrivingRoute(origin: origin, destination: dest);
      if (!mounted) return;

      setState(() {
        _entrega = entrega;
        _route = route;
        _loading = false;
      });

      // Camera fit after first build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitRoute();
      });
    } catch (e) {
      debugPrint('EntregaRouteMapScreen._load error: $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool _hasCoords(EnderecoCarga? e) => e?.latitude != null && e?.longitude != null;

  void _fitRoute() {
    final entrega = _entrega;
    final route = _route;
    final origem = entrega?.carga?.origem;
    final destino = entrega?.carga?.destino;
    if (!_hasCoords(origem) || !_hasCoords(destino)) return;

    final origin = LatLng(origem!.latitude!, origem.longitude!);
    final dest = LatLng(destino!.latitude!, destino.longitude!);
    final points = (route?.polyline.isNotEmpty ?? false) ? route!.polyline : <LatLng>[origin, dest];
    final bounds = _boundsFor(points);

    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(44)));
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours <= 0) return '${d.inMinutes} min';
    return '${hours}h ${minutes}min';
  }

  double? _estimateFuelLiters(double km) {
    final consumo = widget.consumoKmPorLitro;
    if (consumo <= 0) return null;
    return km / consumo;
  }

  Future<void> _openEntregaDetails() async {
    final entrega = _entrega;
    if (entrega == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => EntregaDetailsSheet(entrega: entrega),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(context)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.surface.withValues(alpha: 0.78), cs.surface.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _FloatingIconButton(
                    icon: Icons.arrow_back,
                    label: 'Voltar',
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (_route != null)
                    _FloatingIconButton(
                      icon: Icons.center_focus_strong,
                      label: 'Centralizar',
                      onTap: _fitRoute,
                    ),
                  const Spacer(),
                  _MapZoomButtons(controller: _mapController),
                ],
              ),
            ),
          ),
          _RouteBottomPanel(
            loading: _loading,
            error: _error,
            entrega: _entrega,
            route: _route,
            consumoKmPorLitro: widget.consumoKmPorLitro,
            onRefresh: _load,
            onOpenDetails: _openEntregaDetails,
            formatDuration: _formatDuration,
            estimateFuel: _estimateFuelLiters,
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entrega = _entrega;
    final origem = entrega?.carga?.origem;
    final destino = entrega?.carga?.destino;

    final hasCoords = _hasCoords(origem) && _hasCoords(destino);
    final origin = hasCoords ? LatLng(origem!.latitude!, origem.longitude!) : const LatLng(0, 0);
    final dest = hasCoords ? LatLng(destino!.latitude!, destino.longitude!) : const LatLng(0, 0);
    final route = _route;
    final polylinePoints = (route?.polyline.isNotEmpty ?? false) ? route!.polyline : (hasCoords ? <LatLng>[origin, dest] : const <LatLng>[]);
    final bounds = hasCoords ? _boundsFor(polylinePoints.isNotEmpty ? polylinePoints : <LatLng>[origin, dest]) : null;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: bounds == null ? null : CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
        backgroundColor: cs.surfaceContainerHighest,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'motohub'),
        if (polylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(points: polylinePoints, strokeWidth: 5, color: cs.primary.withValues(alpha: 0.88)),
              Polyline(points: polylinePoints, strokeWidth: 10, color: cs.primary.withValues(alpha: 0.18)),
            ],
          ),
        if (hasCoords)
          MarkerLayer(
            markers: [
              _marker(origin, Icons.circle, cs.primary),
              _marker(dest, Icons.location_on, cs.error),
            ],
          ),
      ],
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.32), width: 1),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _RouteBottomPanel extends StatelessWidget {
  final bool loading;
  final Object? error;
  final Entrega? entrega;
  final RouteResult? route;
  final double consumoKmPorLitro;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenDetails;
  final String Function(Duration d) formatDuration;
  final double? Function(double km) estimateFuel;

  const _RouteBottomPanel({
    required this.loading,
    required this.error,
    required this.entrega,
    required this.route,
    required this.consumoKmPorLitro,
    required this.onRefresh,
    required this.onOpenDetails,
    required this.formatDuration,
    required this.estimateFuel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      minChildSize: 0.16,
      initialChildSize: 0.24,
      maxChildSize: 0.62,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.14), width: 1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                  children: [
                    _PanelHeader(entrega: entrega, onOpenDetails: onOpenDetails, onRefresh: onRefresh),
                    const SizedBox(height: AppSpacing.md),
                    if (loading) _PanelLoading(),
                    if (!loading && error != null) _PanelError(error: error, onRefresh: onRefresh),
                    if (!loading && error == null) _PanelContent(route: route, consumoKmPorLitro: consumoKmPorLitro, formatDuration: formatDuration, estimateFuel: estimateFuel, entrega: entrega),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final Entrega? entrega;
  final Future<void> Function() onOpenDetails;
  final Future<void> Function() onRefresh;

  const _PanelHeader({required this.entrega, required this.onOpenDetails, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final code = entrega?.codigo ?? entrega?.carga?.codigo ?? 'Rota';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(code, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Mapa em tela cheia', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onOpenDetails,
          icon: Icon(Icons.receipt_long, color: cs.primary, size: 18),
          label: Text('Detalhes', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Atualizar',
          onPressed: onRefresh,
          icon: Icon(Icons.refresh, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PanelLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Calculando rota...', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRefresh;

  const _PanelError({required this.error, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.error.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Não foi possível calcular a rota agora.\n${error ?? ''}',
              style: context.textStyles.bodySmall?.copyWith(color: cs.onErrorContainer, height: 1.35),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(foregroundColor: cs.error, side: BorderSide(color: cs.error.withValues(alpha: 0.5))),
            child: const Text('Tentar'),
          ),
        ],
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  final Entrega? entrega;
  final RouteResult? route;
  final double consumoKmPorLitro;
  final String Function(Duration d) formatDuration;
  final double? Function(double km) estimateFuel;

  const _PanelContent({
    required this.entrega,
    required this.route,
    required this.consumoKmPorLitro,
    required this.formatDuration,
    required this.estimateFuel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final origem = entrega?.carga?.origem;
    final destino = entrega?.carga?.destino;

    if (origem?.latitude == null || origem?.longitude == null || destino?.latitude == null || destino?.longitude == null) {
      return Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.14), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Essa entrega não tem coordenadas de origem/destino para mostrar a rota no mapa.',
                style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    final r = route;
    if (r == null) {
      return Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.14), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Rota ainda não disponível. Puxe para atualizar.',
                style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    final distanceKm = r.distanceKm;
    final duration = r.duration;
    final durationText = formatDuration(duration);
    final avgSpeedKmh = duration.inSeconds <= 0 ? 0.0 : (distanceKm / (duration.inSeconds / 3600.0));
    final fuel = estimateFuel(distanceKm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RouteSummaryGrid(
          items: [
            _SummaryItem(icon: Icons.route, title: 'Distância', value: '${distanceKm.toStringAsFixed(1)} km'),
            _SummaryItem(icon: Icons.schedule, title: 'Tempo médio', value: durationText),
            _SummaryItem(icon: Icons.speed, title: 'Velocidade média', value: '${avgSpeedKmh.toStringAsFixed(0)} km/h'),
            _SummaryItem(
              icon: Icons.local_gas_station,
              title: 'Consumo (médio)',
              value: fuel == null ? '-' : '${fuel.toStringAsFixed(1)} L',
              subtitle: '${consumoKmPorLitro.toStringAsFixed(0)} km/L',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _PlacesCard(origem: origem!, destino: destino!),
      ],
    );
  }
}

class _PlacesCard extends StatelessWidget {
  final EnderecoCarga origem;
  final EnderecoCarga destino;
  const _PlacesCard({required this.origem, required this.destino});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(
        children: [
          _PlaceRow(icon: Icons.circle, iconColor: cs.primary, label: 'Origem', value: '${origem.cidade} - ${origem.estado}'),
          const SizedBox(height: AppSpacing.sm),
          _PlaceRow(icon: Icons.location_on, iconColor: cs.error, label: 'Destino', value: '${destino.cidade} - ${destino.estado}'),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _PlaceRow({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(width: 60, child: Text(label, style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
    );
  }
}

class _RouteSummaryGrid extends StatelessWidget {
  final List<_SummaryItem> items;
  const _RouteSummaryGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final crossAxisCount = isNarrow ? 2 : 4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isNarrow ? 1.9 : 2.3,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: items.map((e) => _SummaryCard(item: e)).toList(),
        );
      },
    );
  }
}

class _SummaryItem {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  const _SummaryItem({required this.icon, required this.title, required this.value, this.subtitle});
}

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;
  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(item.value, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(item.subtitle!, style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FloatingIconButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: cs.onSurface),
              const SizedBox(width: 8),
              Text(label, style: context.textStyles.labelMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapZoomButtons extends StatelessWidget {
  final MapController controller;
  const _MapZoomButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom +',
            onPressed: () {
              final camera = controller.camera;
              controller.move(camera.center, camera.zoom + 1);
            },
            icon: Icon(Icons.add, color: cs.onSurface),
          ),
          Container(height: 1, width: 40, color: cs.outline.withValues(alpha: 0.12)),
          IconButton(
            tooltip: 'Zoom -',
            onPressed: () {
              final camera = controller.camera;
              controller.move(camera.center, camera.zoom - 1);
            },
            icon: Icon(Icons.remove, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}
