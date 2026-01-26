import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing location tracking
class LocationService {
  Timer? _trackingTimer;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Check permission status
      var permission = await Permission.location.status;
      if (permission.isDenied) {
        permission = await Permission.location.request();
      }

      if (permission.isPermanentlyDenied) {
        debugPrint('Location permission permanently denied');
        await openAppSettings();
        return false;
      }

      return permission.isGranted;
    } catch (e) {
      debugPrint('Check permissions error: $e');
      return false;
    }
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      return position;
    } catch (e) {
      debugPrint('Get current position error: $e');
      return null;
    }
  }

  /// Start tracking location for active delivery
  Future<void> startTracking(String motoristaEmail, String entregaId) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        debugPrint('No location permission for tracking');
        return;
      }

      // Stop any existing tracking
      stopTracking();

      // Start periodic updates (every 10 seconds)
      _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        await _updateLocation(motoristaEmail, entregaId);
      });

      // Send initial update immediately
      await _updateLocation(motoristaEmail, entregaId);
    } catch (e) {
      debugPrint('Start tracking error: $e');
    }
  }

  /// Stop tracking location
  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _lastPosition = null;
    _lastUpdateTime = null;
  }

  /// Update location to database
  Future<void> _updateLocation(String motoristaEmail, String entregaId) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return;

      // Calculate speed if we have previous position
      double? speed;
      final lastPos = _lastPosition;
      final lastTime = _lastUpdateTime;
      if (lastPos != null && lastTime != null) {
        final distance = Geolocator.distanceBetween(
          lastPos.latitude,
          lastPos.longitude,
          position.latitude,
          position.longitude,
        );
        final timeElapsed = DateTime.now().difference(lastTime).inSeconds;
        if (timeElapsed > 0) {
          speed = (distance / timeElapsed) * 3.6; // Convert m/s to km/h
        }
      }

      // Update localizações table
      await SupabaseConfig.client
          .from('localizações')
          .upsert({
            'email_motorista': motoristaEmail,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'precisao': position.accuracy,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'heading': position.heading,
            'status': true,
            'visivel': true,
          }, onConflict: 'email_motorista');

      // Insert tracking history
      await SupabaseConfig.client
          .from('tracking_historico')
          .insert({
            'entrega_id': entregaId,
            // Mantemos o histórico marcado como "em rota" no novo enum.
            'status': StatusEntrega.saiuParaEntrega.value,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'observacao': speed != null ? 'Velocidade: ${speed.toStringAsFixed(1)} km/h' : null,
            'created_at': DateTime.now().toIso8601String(),
          });

      _lastPosition = position;
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      debugPrint('Update location error: $e');
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Validate if driver is near destination (geofence)
  Future<bool> isNearDestination(double destLat, double destLon, {double radiusMeters = 200}) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return false;

      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        destLat,
        destLon,
      );

      return distance <= radiusMeters;
    } catch (e) {
      debugPrint('Is near destination error: $e');
      return false;
    }
  }
}
