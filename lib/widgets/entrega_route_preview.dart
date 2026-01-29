import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hubfrete/models/carga.dart';
import 'package:hubfrete/services/route_service.dart';
import 'package:hubfrete/theme.dart';

/// Compact, non-interactive map preview for an entrega route (origem -> destino).
///
/// Requires latitude/longitude in both origem and destino. If coordinates are
/// missing, this widget will render a lightweight placeholder.
class EntregaRoutePreview extends StatefulWidget {
  final EnderecoCarga? origem;
  final EnderecoCarga? destino;
  final double height;

  /// If provided, used to estimate fuel consumption in liters.
  /// Example: 25 means 25 km/L.
  final double? consumoKmPorLitro;

  const EntregaRoutePreview({
    super.key,
    required this.origem,
    required this.destino,
    this.height = 160,
    this.consumoKmPorLitro,
  });

  @override
  State<EntregaRoutePreview> createState() => _EntregaRoutePreviewState();
}

/// Route metrics (distance, ETA, fuel estimate) without rendering a map.
///
/// This is meant for compact surfaces like list cards.
class EntregaRouteMetrics extends StatefulWidget {
  final EnderecoCarga? origem;
  final EnderecoCarga? destino;

  /// If provided, used to estimate fuel consumption in liters.
  /// Example: 25 means 25 km/L.
  final double? consumoKmPorLitro;

  const EntregaRouteMetrics({
    super.key,
    required this.origem,
    required this.destino,
    this.consumoKmPorLitro,
  });

  @override
  State<EntregaRouteMetrics> createState() => _EntregaRouteMetricsState();
}

class _EntregaRouteMetricsState extends State<EntregaRouteMetrics> {
  late final Future<RouteResult?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RouteResult?> _load() async {
    final o = widget.origem;
    final d = widget.destino;
    if (o?.latitude == null || o?.longitude == null || d?.latitude == null || d?.longitude == null) {
      return null;
    }

    final origin = LatLng(o!.latitude!, o.longitude!);
    final dest = LatLng(d!.latitude!, d.longitude!);

    final cached = RouteService.instance.getCached(origin, dest);
    if (cached != null) return cached;

    return RouteService.instance.getDrivingRoute(origin: origin, destination: dest);
  }

  @override
  Widget build(BuildContext context) {
    final origem = widget.origem;
    final destino = widget.destino;
    final hasCoords = origem?.latitude != null && origem?.longitude != null && destino?.latitude != null && destino?.longitude != null;
    if (!hasCoords) {
      return _MissingCoordsPlaceholder(height: 56);
    }

    return FutureBuilder<RouteResult?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LoadingPlaceholder(height: 56);
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _RouteErrorPlaceholder(height: 56);
        }

        final route = snapshot.data!;
        final fuel = _estimateFuelLiters(route.distanceKm);
        final durationText = _formatDuration(route.duration);
        final distanceText = '${route.distanceKm.toStringAsFixed(1)} km';
        return Align(
          alignment: Alignment.centerLeft,
          child: _MetricsPill(distanceText: distanceText, durationText: durationText, fuelLiters: fuel),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours <= 0) return '${d.inMinutes} min';
    return '${hours}h ${minutes}min';
  }

  double? _estimateFuelLiters(double km) {
    final consumo = widget.consumoKmPorLitro;
    if (consumo == null || consumo <= 0) return null;
    return km / consumo;
  }
}

class _EntregaRoutePreviewState extends State<EntregaRoutePreview> {
  late final Future<RouteResult?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RouteResult?> _load() async {
    final o = widget.origem;
    final d = widget.destino;
    if (o?.latitude == null || o?.longitude == null || d?.latitude == null || d?.longitude == null) {
      return null;
    }

    final origin = LatLng(o!.latitude!, o.longitude!);
    final dest = LatLng(d!.latitude!, d.longitude!);

    // Fast-path cache.
    final cached = RouteService.instance.getCached(origin, dest);
    if (cached != null) return cached;

    return RouteService.instance.getDrivingRoute(origin: origin, destination: dest);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: widget.height,
        child: FutureBuilder<RouteResult?>(
          future: _future,
          builder: (context, snapshot) {
            final origem = widget.origem;
            final destino = widget.destino;
            final hasCoords = origem?.latitude != null && origem?.longitude != null && destino?.latitude != null && destino?.longitude != null;

            if (!hasCoords) {
              return _MissingCoordsPlaceholder(height: widget.height);
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _LoadingPlaceholder(height: widget.height);
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _RouteErrorPlaceholder(height: widget.height);
            }

            final route = snapshot.data!;
            final origin = LatLng(origem!.latitude!, origem.longitude!);
            final dest = LatLng(destino!.latitude!, destino.longitude!);
            final bounds = _boundsFor(route.polyline.isNotEmpty ? route.polyline : [origin, dest]);

            final fuel = _estimateFuelLiters(route.distanceKm);
            final durationText = _formatDuration(route.duration);
            final distanceText = '${route.distanceKm.toStringAsFixed(1)} km';

            return Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(22)),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'motohub',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route.polyline,
                          strokeWidth: 4,
                          color: cs.primary.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        _marker(origin, Icons.circle, cs.primary),
                        _marker(dest, Icons.location_on, cs.error),
                      ],
                    ),
                  ],
                ),

                // Bottom metrics overlay
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: _MetricsPill(
                      distanceText: distanceText,
                      durationText: durationText,
                      fuelLiters: fuel,
                    ),
                  ),
                ),

                // Top gradient for readability
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.surface.withValues(alpha: 0.65),
                          cs.surface.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
    if (consumo == null || consumo <= 0) return null;
    return km / consumo;
  }

  Marker _marker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _MetricsPill extends StatelessWidget {
  final String distanceText;
  final String durationText;
  final double? fuelLiters;

  const _MetricsPill({
    required this.distanceText,
    required this.durationText,
    required this.fuelLiters,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textStyle = context.textStyles.labelMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700);

    final items = <Widget>[
      _Chip(icon: Icons.route, text: distanceText),
      _Chip(icon: Icons.schedule, text: durationText),
    ];

    if (fuelLiters != null) {
      items.add(_Chip(icon: Icons.local_gas_station, text: '${fuelLiters!.toStringAsFixed(1)} L'));
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18), width: 1),
      ),
      child: DefaultTextStyle(
        style: textStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: items,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 4),
        Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  final double height;
  const _LoadingPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      ),
    );
  }
}

class _RouteErrorPlaceholder extends StatelessWidget {
  final double height;
  const _RouteErrorPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: AppSpacing.paddingMd,
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.map_outlined, color: cs.outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Não foi possível calcular a rota agora',
              style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingCoordsPlaceholder extends StatelessWidget {
  final double height;
  const _MissingCoordsPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: AppSpacing.paddingMd,
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.location_off_outlined, color: cs.outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Origem/destino sem coordenadas para mostrar no mapa',
              style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
