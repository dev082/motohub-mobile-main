import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hubfrete/models/location_point.dart';
import 'package:hubfrete/models/tracking_state.dart';
import 'package:hubfrete/services/location_database_service.dart';
import 'package:hubfrete/services/location_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Serviço principal de rastreamento de localização
class LocationTrackingService {
  static final LocationTrackingService instance = LocationTrackingService._();
  LocationTrackingService._();

  StreamSubscription<Position>? _positionStream;
  TrackingState _currentState = TrackingState.offline;
  String? _emailMotorista;
  String? _currentEntregaId;
  Position? _lastPosition;
  bool _isTracking = false;

  TrackingState get currentState => _currentState;
  bool get isTracking => _isTracking;

  static const String _keyEmailMotorista = 'tracking_email_motorista';
  static const String _keyTrackingState = 'tracking_state';
  static const String _keyEntregaId = 'tracking_entrega_id';

  /// Inicializa o serviço e restaura estado salvo
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _emailMotorista = prefs.getString(_keyEmailMotorista);
      final stateStr = prefs.getString(_keyTrackingState);
      _currentState = stateStr != null ? TrackingState.fromString(stateStr) : TrackingState.offline;
      _currentEntregaId = prefs.getString(_keyEntregaId);

      // Se estava rastreando antes do app fechar, retoma
      if (_currentState != TrackingState.offline && _emailMotorista != null) {
        debugPrint('[LocationTracking] Retomando rastreamento: $_currentState');
        await _startTracking();
      }
    } catch (e) {
      debugPrint('[LocationTracking] Erro ao inicializar: $e');
    }
  }

  /// Inicia o rastreamento para um motorista
  Future<void> startTracking({
    required String emailMotorista,
    required TrackingState initialState,
    String? entregaId,
  }) async {
    try {
      _emailMotorista = emailMotorista;
      _currentState = initialState;
      _currentEntregaId = entregaId;

      // Persiste estado
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmailMotorista, emailMotorista);
      await prefs.setString(_keyTrackingState, initialState.value);
      if (entregaId != null) {
        await prefs.setString(_keyEntregaId, entregaId);
      } else {
        await prefs.remove(_keyEntregaId);
      }

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
      _emailMotorista = null;
      _currentEntregaId = null;
      _lastPosition = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEmailMotorista);
      await prefs.remove(_keyTrackingState);
      await prefs.remove(_keyEntregaId);

      debugPrint('[LocationTracking] Rastreamento parado');
    } catch (e) {
      debugPrint('[LocationTracking] Erro ao parar rastreamento: $e');
    }
  }

  /// Atualiza o estado de rastreamento (muda precisão/intervalo)
  Future<void> updateTrackingState(TrackingState newState, {String? entregaId}) async {
    if (_currentState == newState && _currentEntregaId == entregaId) return;

    _currentState = newState;
    _currentEntregaId = entregaId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTrackingState, newState.value);
    if (entregaId != null) {
      await prefs.setString(_keyEntregaId, entregaId);
    } else {
      await prefs.remove(_keyEntregaId);
    }

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

    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: _getAccuracyForState(_currentState),
        distanceFilter: config.distanceFilterMeters.toInt(),
        intervalDuration: Duration(seconds: config.intervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Rastreamento ativo - HubFrete Motoristas',
          notificationTitle: 'Motorista em rota',
          enableWakeLock: true,
        ),
      ),
    ).listen(
      _onPositionUpdate,
      onError: (error) => debugPrint('[LocationTracking] Erro no stream: $error'),
    );

    _isTracking = true;
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
    if (_emailMotorista == null) return;

    final heading = _calculateHeading(position);
    final point = LocationPoint(
      id: const Uuid().v4(),
      emailMotorista: _emailMotorista!,
      entregaId: _currentEntregaId,
      latitude: position.latitude,
      longitude: position.longitude,
      precisao: position.accuracy,
      velocidade: position.speed,
      heading: heading,
      timestamp: position.timestamp ?? DateTime.now(),
      status: _currentState.value,
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

  /// Solicita permissões de localização
  Future<LocationPermission> requestPermissions() async {
    return await Geolocator.requestPermission();
  }
}
