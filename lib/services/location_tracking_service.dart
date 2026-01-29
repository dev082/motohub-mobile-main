import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hubfrete/models/location_point.dart';
import 'package:hubfrete/models/tracking_state.dart';
import 'package:hubfrete/services/location_database_service.dart';
import 'package:hubfrete/services/location_sync_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Snapshot consolidado das permissões/requisitos para rastreamento funcionar bem.
class TrackingReadiness {
  final LocationPermission locationPermission;
  final bool notificationGranted;
  final bool ignoreBatteryOptimizationsGranted;

  const TrackingReadiness({
    required this.locationPermission,
    required this.notificationGranted,
    required this.ignoreBatteryOptimizationsGranted,
  });

  bool get hasAnyLocation =>
      locationPermission == LocationPermission.always || locationPermission == LocationPermission.whileInUse;

  bool get hasAlwaysLocation => locationPermission == LocationPermission.always;

  /// Regras práticas:
  /// - Precisa de localização (always/whileInUse)
  /// - No Android, para manter o foreground service do Geolocator com notificação persistente,
  ///   é necessário ter permissão de notificação (Android 13+).
  bool get canStartTracking {
    if (!hasAnyLocation) return false;
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) return notificationGranted;
    return true;
  }
}

/// Serviço principal de rastreamento de localização
class LocationTrackingService {
  static final LocationTrackingService instance = LocationTrackingService._();
  LocationTrackingService._();

  StreamSubscription<Position>? _positionStream;
  TrackingState _currentState = TrackingState.offline;
  String? _motoristaId;
  Position? _lastPosition;
  bool _isTracking = false;

  TrackingState get currentState => _currentState;
  bool get isTracking => _isTracking;

  static const String _keyMotoristaId = 'tracking_motorista_id';
  static const String _keyTrackingState = 'tracking_state';

  /// Inicializa o serviço e restaura estado salvo
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _motoristaId = prefs.getString(_keyMotoristaId);
      final stateStr = prefs.getString(_keyTrackingState);
      _currentState = stateStr != null ? TrackingState.fromString(stateStr) : TrackingState.offline;

      // Se estava rastreando antes do app fechar, retoma
      if (_currentState != TrackingState.offline && _motoristaId != null) {
        debugPrint('[LocationTracking] Retomando rastreamento: $_currentState');
        await _startTracking();
      }
    } catch (e) {
      debugPrint('[LocationTracking] Erro ao inicializar: $e');
    }
  }

  /// Inicia o rastreamento para um motorista
  Future<void> startTracking({
    required String motoristaId,
    required TrackingState initialState,
  }) async {
    try {
      _motoristaId = motoristaId;
      _currentState = initialState;

      // Persiste estado
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMotoristaId, motoristaId);
      await prefs.setString(_keyTrackingState, initialState.value);

      await _startTracking();
      LocationSyncService.instance.startPeriodicSync();
      debugPrint('[LocationTracking] Rastreamento iniciado: $initialState');
    } catch (e) {
      debugPrint('[LocationTracking] Erro ao iniciar rastreamento: $e');
      rethrow;
    }
  }

  /// Para o rastreamento
  Future<void> stopTracking() async {
    try {
      await _stopTracking();
      LocationSyncService.instance.stopPeriodicSync();

      _currentState = TrackingState.offline;
      _motoristaId = null;
      _lastPosition = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyMotoristaId);
      await prefs.remove(_keyTrackingState);

      debugPrint('[LocationTracking] Rastreamento parado');
    } catch (e) {
      debugPrint('[LocationTracking] Erro ao parar rastreamento: $e');
    }
  }

  /// Atualiza o estado de rastreamento (muda precisão/intervalo)
  Future<void> updateTrackingState(TrackingState newState) async {
    if (_currentState == newState) return;

    _currentState = newState;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTrackingState, newState.value);

    // Reinicia o stream com nova configuração
    if (_isTracking) {
      await _stopTracking();
      await _startTracking();
    }

    debugPrint('[LocationTracking] Estado atualizado: $newState');
  }

  Future<void> _startTracking() async {
    if (_isTracking) return;

    final config = TrackingConfig.forState(_currentState);
    if (config.intervalSeconds == 0) return;

    final locationSettings = _buildLocationSettings(config);

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      _onPositionUpdate,
      onError: (error) => debugPrint('[LocationTracking] Erro no stream: $error'),
    );

    _isTracking = true;
  }

  LocationSettings _buildLocationSettings(TrackingConfig config) {
    // Web e iOS não suportam AndroidSettings.
    if (kIsWeb) {
      return LocationSettings(accuracy: _getAccuracyForState(_currentState), distanceFilter: config.distanceFilterMeters.toInt());
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: _getAccuracyForState(_currentState),
        distanceFilter: config.distanceFilterMeters.toInt(),
        intervalDuration: Duration(seconds: config.intervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Rastreamento ativo - HubFrete Motoristas',
          notificationTitle: 'Motorista em rota',
          enableWakeLock: true,
        ),
      );
    }

    return AppleSettings(
      accuracy: _getAccuracyForState(_currentState),
      distanceFilter: config.distanceFilterMeters.toInt(),
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );
  }

  Future<void> _stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
  }

  LocationAccuracy _getAccuracyForState(TrackingState state) {
    switch (state) {
      case TrackingState.offline:
        return LocationAccuracy.lowest;
      case TrackingState.onlineSemEntrega:
        return LocationAccuracy.medium;
      case TrackingState.emRotaColeta:
        return LocationAccuracy.high;
      case TrackingState.emEntrega:
        return LocationAccuracy.best;
      case TrackingState.finalizado:
        return LocationAccuracy.low;
    }
  }

  void _onPositionUpdate(Position position) {
    if (_motoristaId == null) return;

    final heading = _calculateHeading(position);
    final point = LocationPoint(
      id: const Uuid().v4(),
      motoristaId: _motoristaId!,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      precisao: position.accuracy,
      velocidade: position.speed,
      heading: heading,
      timestamp: position.timestamp ?? DateTime.now(),
    );

    // Salva na fila local
    LocationDatabaseService.instance.insertPoint(point).catchError((e) {
      debugPrint('[LocationTracking] Erro ao salvar ponto: $e');
    });

    _lastPosition = position;
  }

  /// Calcula heading (direção) baseado em variação entre pontos
  double? _calculateHeading(Position currentPosition) {
    if (_lastPosition == null) return null;
    if (currentPosition.speed < 3.0) return null; // Só calcular se velocidade > 3 m/s

    final lat1 = _lastPosition!.latitude * pi / 180;
    final lat2 = currentPosition.latitude * pi / 180;
    final lon1 = _lastPosition!.longitude * pi / 180;
    final lon2 = currentPosition.longitude * pi / 180;

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x) * 180 / pi;

    return (bearing + 360) % 360;
  }

  /// Força envio imediato de dados
  Future<void> forceSyncNow() async {
    await LocationSyncService.instance.forceSyncNow();
  }

  /// Verifica status das permissões
  Future<bool> checkPermissions() async {
    final status = await Geolocator.checkPermission();
    return status == LocationPermission.always || status == LocationPermission.whileInUse;
  }

  Future<TrackingReadiness> getTrackingReadiness() async {
    final location = await Geolocator.checkPermission();
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final notifications = !isAndroid ? true : await ph.Permission.notification.isGranted;
    final battery = !isAndroid ? true : await ph.Permission.ignoreBatteryOptimizations.isGranted;
    return TrackingReadiness(
      locationPermission: location,
      notificationGranted: notifications,
      ignoreBatteryOptimizationsGranted: battery,
    );
  }

  /// Solicita permissões de localização
  Future<LocationPermission> requestPermissions() async {
    return await Geolocator.requestPermission();
  }
}
