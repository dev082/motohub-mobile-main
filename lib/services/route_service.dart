import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result of a route query.
class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000.0;
  Duration get duration => Duration(seconds: durationSeconds.round());
}

/// Fetches driving routes and metrics using OSRM.
///
/// Notes:
/// - Uses the public OSRM demo server (no API key).
/// - Includes a small in-memory cache to avoid repeated calls while scrolling.
class RouteService {
  static final RouteService instance = RouteService._();
  RouteService._();

  static const String _baseUrl = 'https://router.project-osrm.org';
  static const int _maxCacheEntries = 50;

  final Map<String, RouteResult> _cache = <String, RouteResult>{};
  final List<String> _lru = <String>[];

  String _cacheKey(LatLng origin, LatLng destination) {
    String f(double v) => v.toStringAsFixed(5);
    return '${f(origin.latitude)},${f(origin.longitude)}->${f(destination.latitude)},${f(destination.longitude)}';
  }

  RouteResult? getCached(LatLng origin, LatLng destination) {
    final key = _cacheKey(origin, destination);
    final value = _cache[key];
    if (value != null) {
      _touch(key);
    }
    return value;
  }

  void _touch(String key) {
    _lru.remove(key);
    _lru.insert(0, key);
  }

  void _putCache(String key, RouteResult value) {
    _cache[key] = value;
    _touch(key);
    while (_lru.length > _maxCacheEntries) {
      final removeKey = _lru.removeLast();
      _cache.remove(removeKey);
    }
  }

  Future<RouteResult> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    http.Client? client,
  }) async {
    final key = _cacheKey(origin, destination);
    final cached = _cache[key];
    if (cached != null) {
      _touch(key);
      return cached;
    }

    final httpClient = client ?? http.Client();
    try {
      // OSRM expects lon,lat order.
      final uri = Uri.parse(
        '$_baseUrl/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&alternatives=false&steps=false',
      );

      final res = await httpClient.get(uri, headers: const {'accept': 'application/json'});
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('OSRM HTTP ${res.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('OSRM response inválida');
      }

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) {
        throw Exception('OSRM sem rota');
      }

      final first = routes.first;
      if (first is! Map<String, dynamic>) {
        throw Exception('OSRM rota inválida');
      }

      final distance = (first['distance'] as num?)?.toDouble();
      final duration = (first['duration'] as num?)?.toDouble();
      final geometry = first['geometry'];

      if (distance == null || duration == null || geometry is! Map<String, dynamic>) {
        throw Exception('OSRM rota incompleta');
      }

      final coords = geometry['coordinates'];
      if (coords is! List) {
        throw Exception('OSRM geometria inválida');
      }

      final polyline = <LatLng>[];
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          polyline.add(LatLng(lat, lon));
        }
      }

      final result = RouteResult(polyline: polyline, distanceMeters: distance, durationSeconds: duration);
      _putCache(key, result);
      return result;
    } catch (e) {
      debugPrint('RouteService.getDrivingRoute error: $e');
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
