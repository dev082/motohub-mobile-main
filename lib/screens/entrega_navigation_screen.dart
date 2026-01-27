import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:motohub/models/carga.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/services/location_tracking_service.dart';
import 'package:motohub/services/route_service.dart';
import 'package:motohub/theme.dart';

/// Tela de navegação em tempo real (estilo “iniciar rota”).
///
/// Mostra:
/// - posição do motorista em tempo real
/// - rota calculada (OSRM) até o destino
/// - seta (heading) indicando direção / próximo trecho
/// - km restantes até o destino (aprox., ao longo da rota)
class EntregaNavigationScreen extends StatefulWidget {
  final String entregaId;
  const EntregaNavigationScreen({super.key, required this.entregaId});

  @override
  State<EntregaNavigationScreen> createState() => _EntregaNavigationScreenState();
}

class _EntregaNavigationScreenState extends State<EntregaNavigationScreen> {
  final _mapController = MapController();
  final _entregaService = EntregaService();

  Entrega? _entrega;
  RouteResult? _route;
  Object? _error;
  bool _loading = true;

  StreamSubscription<Position>? _posSub;
  Position? _position;

  bool _followUser = true;
  bool _followHeading = true;
  double _mapRotationDeg = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
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

      // Calcula rota (cacheado) do ponto de origem->destino.
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

      // Inicia stream de localização (UI) e centraliza.
      await _startLivePosition();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitInitialCamera();
      });
    } catch (e) {
      debugPrint('EntregaNavigationScreen._load error: $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool _hasCoords(EnderecoCarga? e) => e?.latitude != null && e?.longitude != null;

  Future<void> _startLivePosition() async {
    _posSub?.cancel();

    // Aproveita a checagem robusta do tracking service (permissões + serviços).
    final ok = await LocationTrackingService.instance.checkPermissions();
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _error = LocationTrackingService.instance.lastError ?? 'Sem permissão de localização.';
      });
      return;
    }

    // Prime: pega a posição atual antes do stream começar.
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _position = current);
    } catch (e) {
      debugPrint('EntregaNavigationScreen prime position error: $e');
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      _maybeFollow(pos);
    }, onError: (e) {
      debugPrint('EntregaNavigationScreen position stream error: $e');
      if (!mounted) return;
      setState(() => _error = 'Falha no stream de localização: $e');
    });
  }

  void _fitInitialCamera() {
    final route = _route;
    final entrega = _entrega;
    final origem = entrega?.carga?.origem;
    final destino = entrega?.carga?.destino;
    if (!_hasCoords(origem) || !_hasCoords(destino)) return;

    final origin = LatLng(origem!.latitude!, origem.longitude!);
    final dest = LatLng(destino!.latitude!, destino.longitude!);
    final points = (route?.polyline.isNotEmpty ?? false) ? route!.polyline : <LatLng>[origin, dest];
    final bounds = _boundsFor(points);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(64)));
  }

  void _maybeFollow(Position pos) {
    if (!_followUser) return;

    final center = LatLng(pos.latitude, pos.longitude);
    // Mantém zoom atual para não ficar “pulsando”.
    final zoom = _mapController.camera.zoom;
    _mapController.move(center, zoom);

    if (_followHeading) {
      final heading = _safeHeadingDeg(pos.heading);
      // Inverte para “rotação do mapa” (map rotates opposite to device heading)
      final desired = -heading;
      final delta = (desired - _mapRotationDeg).abs();
      if (delta > 2) {
        _mapRotationDeg = desired;
        try {
          _mapController.rotate(desired);
        } catch (e) {
          // Nem todas as plataformas suportam rotação da mesma forma.
          debugPrint('Map rotate failed: $e');
        }
      }
    }
  }

  double _safeHeadingDeg(double heading) {
    if (heading.isNaN || heading.isInfinite) return 0;
    // Geolocator pode mandar 0 quando sem dados.
    if (heading < 0) return 0;
    return heading % 360;
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
                height: 170,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.surface.withValues(alpha: 0.82), cs.surface.withValues(alpha: 0)],
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
                  _PillButton(icon: Icons.arrow_back, label: 'Voltar', onTap: context.pop),
                  const SizedBox(width: AppSpacing.sm),
                  _PillButton(
                    icon: _followUser ? Icons.my_location : Icons.location_searching,
                    label: _followUser ? 'Seguindo' : 'Livre',
                    onTap: () => setState(() => _followUser = !_followUser),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PillButton(
                    icon: _followHeading ? Icons.explore : Icons.explore_off,
                    label: _followHeading ? 'Bússola' : 'Norte',
                    onTap: () {
                      setState(() => _followHeading = !_followHeading);
                      final pos = _position;
                      if (pos != null) _maybeFollow(pos);
                      if (!_followHeading) {
                        _mapRotationDeg = 0;
                        try {
                          _mapController.rotate(0);
                        } catch (_) {}
                      }
                    },
                  ),
                  const Spacer(),
                  _ZoomButtons(controller: _mapController),
                ],
              ),
            ),
          ),
          _NavBottomPanel(
            loading: _loading,
            error: _error,
            entrega: _entrega,
            route: _route,
            position: _position,
            onRefresh: _load,
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
    final route = _route;
    final pos = _position;

    final hasCoords = _hasCoords(origem) && _hasCoords(destino);
    final origin = hasCoords ? LatLng(origem!.latitude!, origem.longitude!) : const LatLng(0, 0);
    final dest = hasCoords ? LatLng(destino!.latitude!, destino.longitude!) : const LatLng(0, 0);
    final polylinePoints = (route?.polyline.isNotEmpty ?? false)
        ? route!.polyline
        : (hasCoords ? <LatLng>[origin, dest] : const <LatLng>[]);

    final userLatLng = pos == null ? null : LatLng(pos.latitude, pos.longitude);
    final heading = pos == null ? 0.0 : _safeHeadingDeg(pos.heading);
    final arrowBearing = userLatLng == null ? 0.0 : _computeGuidanceBearing(userLatLng, polylinePoints, heading);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: hasCoords ? dest : const LatLng(0, 0),
        initialZoom: 14,
        backgroundColor: cs.surfaceContainerHighest,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'motohub'),
        if (polylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(points: polylinePoints, strokeWidth: 5, color: cs.primary.withValues(alpha: 0.9)),
              Polyline(points: polylinePoints, strokeWidth: 10, color: cs.primary.withValues(alpha: 0.18)),
            ],
          ),
        if (hasCoords)
          MarkerLayer(
            markers: [
              _pin(origin, Icons.circle, cs.primary),
              _pin(dest, Icons.location_on, cs.error),
            ],
          ),
        if (userLatLng != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userLatLng,
                width: 64,
                height: 64,
                child: _UserArrowMarker(angleDeg: arrowBearing, accuracyMeters: pos?.accuracy),
              ),
            ],
          ),
      ],
    );
  }

  Marker _pin(LatLng point, IconData icon, Color color) => Marker(
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

  /// Retorna o bearing que deve ser usado para orientar a seta do motorista.
  ///
  /// Estratégia:
  /// - se existir rota: mira num ponto “à frente” (lookahead) na polyline
  /// - senão: usa o heading do GPS
  double _computeGuidanceBearing(LatLng user, List<LatLng> polyline, double gpsHeadingDeg) {
    if (polyline.length < 2) return gpsHeadingDeg;
    final progress = _progressOnPolyline(user, polyline);
    if (progress == null) return gpsHeadingDeg;
    final lookahead = _lookAheadPoint(polyline, progress.segmentIndex, progress.tMetersOnSegment, metersAhead: 60);
    if (lookahead == null) return gpsHeadingDeg;
    return _bearingDeg(user, lookahead);
  }

  ({int segmentIndex, double tMetersOnSegment, LatLng snapped})? _progressOnPolyline(LatLng user, List<LatLng> polyline) {
    if (polyline.length < 2) return null;
    const dist = Distance();

    double bestMeters = double.infinity;
    int bestSeg = 0;
    double bestTMeters = 0;
    LatLng bestSnap = polyline.first;

    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final snap = _snapToSegment(user, a, b);
      final d = dist(user, snap);
      if (d < bestMeters) {
        bestMeters = d;
        bestSeg = i;
        bestSnap = snap;
        // tMeters: quanto já “andou” no segmento a->b até o ponto snapped.
        bestTMeters = dist(a, snap);
      }
    }

    return (segmentIndex: bestSeg, tMetersOnSegment: bestTMeters, snapped: bestSnap);
  }

  LatLng? _lookAheadPoint(List<LatLng> polyline, int segIndex, double tMetersOnSeg, {required double metersAhead}) {
    const dist = Distance();
    var remaining = metersAhead;

    // Começa no ponto snapped dentro do segmento atual.
    var a = polyline[segIndex];
    var b = polyline[segIndex + 1];
    final segLen = dist(a, b);
    final remainOnSeg = math.max(0.0, segLen - tMetersOnSeg);

    if (remainOnSeg >= remaining && segLen > 0) {
      final t = (tMetersOnSeg + remaining) / segLen;
      return _lerpLatLng(a, b, t);
    }

    remaining -= remainOnSeg;
    for (var i = segIndex + 1; i < polyline.length - 1; i++) {
      a = polyline[i];
      b = polyline[i + 1];
      final len = dist(a, b);
      if (len >= remaining && len > 0) {
        final t = remaining / len;
        return _lerpLatLng(a, b, t);
      }
      remaining -= len;
    }
    return polyline.last;
  }

  LatLng _snapToSegment(LatLng p, LatLng a, LatLng b) {
    // Aproximação plana (equirectangular) suficiente para poucos km.
    final lat0 = (a.latitude + b.latitude) / 2;
    final kx = math.cos(lat0 * math.pi / 180);

    final ax = a.longitude * kx;
    final ay = a.latitude;
    final bx = b.longitude * kx;
    final by = b.latitude;
    final px = p.longitude * kx;
    final py = p.latitude;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;
    final ab2 = abx * abx + aby * aby;
    if (ab2 == 0) return a;
    var t = (apx * abx + apy * aby) / ab2;
    t = t.clamp(0.0, 1.0);
    final sx = ax + abx * t;
    final sy = ay + aby * t;
    return LatLng(sy, sx / kx);
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  double _bearingDeg(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }
}

class _UserArrowMarker extends StatelessWidget {
  final double angleDeg;
  final double? accuracyMeters;
  const _UserArrowMarker({required this.angleDeg, this.accuracyMeters});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final acc = accuracyMeters;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (acc != null && acc.isFinite && acc > 0)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary.withValues(alpha: 0.18), width: 1),
            ),
          ),
        Transform.rotate(
          angle: angleDeg * math.pi / 180,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(Icons.navigation, color: cs.primary, size: 22),
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.icon, required this.label, required this.onTap});

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

class _ZoomButtons extends StatelessWidget {
  final MapController controller;
  const _ZoomButtons({required this.controller});

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

class _NavBottomPanel extends StatelessWidget {
  final bool loading;
  final Object? error;
  final Entrega? entrega;
  final RouteResult? route;
  final Position? position;
  final Future<void> Function() onRefresh;

  const _NavBottomPanel({
    required this.loading,
    required this.error,
    required this.entrega,
    required this.route,
    required this.position,
    required this.onRefresh,
  });

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours <= 0) return '${d.inMinutes} min';
    return '${hours}h ${minutes}min';
  }

  double? _remainingKm(RouteResult route, EnderecoCarga destino, Position? pos) {
    if (pos == null) return null;
    final poly = route.polyline;
    if (poly.length < 2) {
      final meters = Geolocator.distanceBetween(pos.latitude, pos.longitude, destino.latitude!, destino.longitude!);
      return meters / 1000;
    }

    // Recalcula progressão similar à tela principal (simplificada aqui para o painel).
    // Isso mantém o painel independente do estado do mapa.
    const dist = Distance();
    final user = LatLng(pos.latitude, pos.longitude);

    double bestMeters = double.infinity;
    int bestSeg = 0;
    LatLng bestSnap = poly.first;

    LatLng snapToSegment(LatLng p, LatLng a, LatLng b) {
      final lat0 = (a.latitude + b.latitude) / 2;
      final kx = math.cos(lat0 * math.pi / 180);
      final ax = a.longitude * kx;
      final ay = a.latitude;
      final bx = b.longitude * kx;
      final by = b.latitude;
      final px = p.longitude * kx;
      final py = p.latitude;
      final abx = bx - ax;
      final aby = by - ay;
      final apx = px - ax;
      final apy = py - ay;
      final ab2 = abx * abx + aby * aby;
      if (ab2 == 0) return a;
      var t = (apx * abx + apy * aby) / ab2;
      t = t.clamp(0.0, 1.0);
      final sx = ax + abx * t;
      final sy = ay + aby * t;
      return LatLng(sy, sx / kx);
    }

    for (var i = 0; i < poly.length - 1; i++) {
      final a = poly[i];
      final b = poly[i + 1];
      final snap = snapToSegment(user, a, b);
      final d = dist(user, snap);
      if (d < bestMeters) {
        bestMeters = d;
        bestSeg = i;
        bestSnap = snap;
      }
    }

    var meters = 0.0;
    // Do ponto snapped até o final.
    meters += dist(bestSnap, poly[bestSeg + 1]);
    for (var i = bestSeg + 1; i < poly.length - 1; i++) {
      meters += dist(poly[i], poly[i + 1]);
    }
    return meters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final destino = entrega?.carga?.destino;
    final r = route;
    final remainingKm = (r != null && destino?.latitude != null && destino?.longitude != null)
        ? _remainingKm(r, destino!, position)
        : null;

    final speedKmh = position?.speed;
    final heading = position?.heading;

    return DraggableScrollableSheet(
      minChildSize: 0.14,
      initialChildSize: 0.22,
      maxChildSize: 0.54,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.14), width: 1)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, AppSpacing.lg),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Navegação', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          entrega?.codigo ?? entrega?.carga?.codigo ?? 'Entrega',
                          style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atualizar rota',
                    onPressed: onRefresh,
                    icon: Icon(Icons.refresh, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (loading)
                Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Calculando rota...', style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
                  ],
                ),
              if (!loading && error != null)
                Container(
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
                          'Não foi possível iniciar a navegação.\n${error ?? ''}',
                          style: context.textStyles.bodySmall?.copyWith(color: cs.onErrorContainer, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!loading && error == null)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MetricChip(
                      icon: Icons.route,
                      label: remainingKm == null ? 'Faltam: --' : 'Faltam: ${remainingKm.toStringAsFixed(1)} km',
                    ),
                    if (r != null)
                      _MetricChip(
                        icon: Icons.schedule,
                        label: 'Estimativa: ${_formatDuration(r.duration)}',
                      ),
                    if (speedKmh != null && speedKmh.isFinite)
                      _MetricChip(icon: Icons.speed, label: '${(speedKmh * 3.6).toStringAsFixed(0)} km/h'),
                    if (heading != null && heading.isFinite)
                      _MetricChip(icon: Icons.explore, label: 'Heading: ${heading.toStringAsFixed(0)}°'),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              if (destino != null)
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.12), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: cs.error, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Destino: ${destino.cidade} - ${destino.estado}',
                          style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(label, style: context.textStyles.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
