import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motohub/models/location_point.dart';
import 'package:motohub/models/tracking_session.dart';
import 'package:motohub/services/cache_service.dart';
import 'package:motohub/supabase/supabase_config.dart';

/// Advanced location tracking service with adaptive intervals and battery optimization
class LocationTrackingService {
  static final LocationTrackingService instance = LocationTrackingService._();
  LocationTrackingService._();

  /// Notifies listeners whenever tracking is started/stopped.
  /// Useful for keeping UI (GPS icon) in sync even when tracking starts automatically.
  final ValueNotifier<bool> isTrackingNotifier = ValueNotifier<bool>(false);

  /// Notifies UI when tracking cannot run reliably in background.
  /// The UI should show a permission/settings prompt when this is non-null.
  final ValueNotifier<TrackingPermissionIssue?> permissionIssueNotifier = ValueNotifier<TrackingPermissionIssue?>(null);

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionStream;
  
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  String? _currentEntregaId;
  String? _currentMotoristaId;
  String? _currentSessionId;
  
  bool _isTracking = false;
  bool _isOnline = true;
  int _batteryLevel = 100;
  String? _lastError;

  // Server uses "tracking_historico" for location history and "localizações" for current position.
  bool _serverTrackingEnabled = true;
  String? _motoristaEmail;
  
  // Adaptive interval settings
  static const int _intervalMovingSeconds = 5; // 5s when moving
  static const int _intervalStationarySeconds = 30; // 30s when stationary
  static const int _intervalLowBatterySeconds = 60; // 60s when battery < 20%
  static const double _stationaryThresholdKmh = 5.0; // < 5 km/h = stationary
  static const int _maxPendingLocations = 100; // Max locations to queue offline

  bool get isTracking => _isTracking;
  String? get currentSessionId => _currentSessionId;
  String? get currentEntregaId => _currentEntregaId;
  String? get lastError => _lastError;

  bool get isServerTrackingEnabled => _serverTrackingEnabled;

  void _setIsTracking(bool value) {
    _isTracking = value;
    if (isTrackingNotifier.value != value) isTrackingNotifier.value = value;
  }

  /// Initialize tracking service
  Future<void> init() async {
    try {
      await CacheService.init();
      _setupConnectivityListener();
      _setupBatteryListener();
      await _restoreTrackingState();
    } catch (e) {
      debugPrint('LocationTrackingService init error: $e');
    }
  }

  /// Setup connectivity listener to detect online/offline
  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      
      if (!wasOnline && _isOnline) {
        debugPrint('Device back online - syncing pending locations');
        _syncPendingLocations();
      }
    });
  }

  /// Setup battery listener for optimization
  void _setupBatteryListener() {
    _battery.onBatteryStateChanged.listen((state) async {
      final level = await _battery.batteryLevel;
      _batteryLevel = level;
      
      if (level < 15 && _isTracking) {
        debugPrint('Low battery detected ($level%) - reducing tracking frequency');
        await _sendNotification(
          'Bateria Baixa',
          'Rastreamento reduzido para economizar bateria ($level%)',
          tipo: 'bateria_baixa',
        );
      }
    });
  }

  /// Check and request permissions.
  ///
  /// When [requireAlways] is true, we enforce background permission ("Sempre")
  /// because the business requirement is continuous tracking during active entregas.
  Future<bool> checkPermissions({bool requireAlways = false}) async {
    try {
      _lastError = null;
      permissionIssueNotifier.value = null;

      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastError = 'Serviço de localização desativado no aparelho.';
        debugPrint('Location services disabled');
        return false;
      }

      // Use Geolocator permission APIs (works better across platforms, including web).
      var permission = await Geolocator.checkPermission();
      debugPrint('Location permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('Location permission after request: $permission');
      }

      if (permission == LocationPermission.deniedForever) {
        _lastError = 'Permissão de localização bloqueada permanentemente.';
        debugPrint('Location permission permanently denied');
        permissionIssueNotifier.value = TrackingPermissionIssue(
          type: TrackingPermissionIssueType.deniedForever,
          message: _lastError!,
        );
        if (!kIsWeb) {
          // On web there is no app settings page to open.
          await Geolocator.openAppSettings();
        }
        return false;
      }

      final ok = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      if (!ok) {
        _lastError = 'Permissão de localização negada.';
        permissionIssueNotifier.value = TrackingPermissionIssue(
          type: TrackingPermissionIssueType.denied,
          message: _lastError!,
        );
        return false;
      }

      // Enforce background permission when required.
      if (requireAlways && !kIsWeb) {
        final isAlways = permission == LocationPermission.always;
        if (!isAlways) {
          // Best effort: ask for "Always" via permission_handler.
          final req = await Permission.locationAlways.request();
          debugPrint('Background location permission request result: $req');
          final after = await Geolocator.checkPermission();
          debugPrint('Location permission after bg request: $after');
          if (after != LocationPermission.always) {
            _lastError = 'Para rastrear em segundo plano, permita Localização "Sempre".';
            permissionIssueNotifier.value = TrackingPermissionIssue(
              type: TrackingPermissionIssueType.backgroundNotAllowed,
              message: _lastError!,
            );
            return false;
          }
        }
      }

      // Android 13+: Foreground tracking via Geolocator uses a notification.
      // If notifications are blocked, the foreground service may fail to start.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final notif = await Permission.notification.status;
        if (!notif.isGranted) {
          final req = await Permission.notification.request();
          debugPrint('Notification permission: $req');
        }
      }

      return true;
    } catch (e) {
      _lastError = 'Erro ao checar permissões de localização.';
      debugPrint('Check permissions error: $e');
      permissionIssueNotifier.value = TrackingPermissionIssue(
        type: TrackingPermissionIssueType.unknown,
        message: _lastError!,
      );
      return false;
    }
  }

  /// Start tracking for a delivery
  Future<bool> startTracking(String entregaId, String motoristaId) async {
    if (_isTracking && _currentEntregaId == entregaId) {
      debugPrint('Tracking already active for this entrega');
      return true;
    }

    try {
      debugPrint('➡️ startTracking(entregaId=$entregaId, motoristaId=$motoristaId)');

      if (SupabaseConfig.auth.currentUser == null) {
        _lastError = 'Você precisa estar autenticado para iniciar o rastreamento.';
        debugPrint('No Supabase Auth session - cannot start tracking');
        return false;
      }

      // Business rule: if a driver has an active entrega, we must be able to track in background.
      final hasPermission = await checkPermissions(requireAlways: true);
      if (!hasPermission) {
        debugPrint('No location permission - cannot start tracking. lastError=$_lastError');
        return false;
      }

      // Get motorista email
      final motorista = await _getMotoristaEmail(motoristaId);
      if (motorista == null) {
        _lastError = 'Não foi possível obter o email do motorista.';
        debugPrint('Failed to get motorista email');
        return false;
      }
      _motoristaEmail = motorista;

      // Stop any existing tracking
      await stopTracking();

      // Set tracking state
      _currentEntregaId = entregaId;
      _currentMotoristaId = motoristaId;
      _currentSessionId = 'tracking-$entregaId-${DateTime.now().millisecondsSinceEpoch}';

      // Save state to cache for recovery
      await _saveTrackingState();

      // Start location updates with adaptive interval
      _setIsTracking(true);
      await _primeAndStartLocationUpdates();

      debugPrint('✅ Tracking started for entrega $entregaId');
      await _sendNotification(
        'Rastreamento Iniciado',
        'Sua localização está sendo compartilhada em tempo real',
        tipo: 'coleta_iniciada',
      );

      return true;
    } catch (e) {
      _lastError = 'Erro ao iniciar rastreamento: $e';
      debugPrint('Start tracking error: $e');
      _setIsTracking(false);
      return false;
    }
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      debugPrint('➡️ stopTracking(session=$_currentSessionId)');
      _trackingTimer?.cancel();
      await _positionStream?.cancel();
      
      // Update motorista location to offline
      if (_motoristaEmail != null) {
        await _updateMotoristaLocation(null, offline: true);
      }

      // Clear state
      await _clearTrackingState();
      
      _setIsTracking(false);
      _currentEntregaId = null;
      _currentMotoristaId = null;
      _currentSessionId = null;
      _motoristaEmail = null;
      _lastPosition = null;
      _lastUpdateTime = null;

      debugPrint('🛑 Tracking stopped');
    } catch (e) {
      debugPrint('Stop tracking error: $e');
    }
  }

  /// Start location updates with adaptive interval
  Future<void> _primeAndStartLocationUpdates() async {
    _trackingTimer?.cancel();
    _positionStream?.cancel();

    // Important: if the driver is stationary, the stream may not emit immediately
    // due to distanceFilter. Prime with a current position so the UI/server
    // sees the first point instantly.
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      debugPrint('📍 Prime position: ${current.latitude}, ${current.longitude}');
      await _handlePositionUpdate(current);
    } catch (e) {
      debugPrint('Prime current position error: $e');
      // Non-fatal: still start the stream.
    }

    // For native Android tracking reliability (especially in background), Geolocator
    // works best with a Position Stream + Foreground Service notification.
    // We still keep our adaptive logic, but we throttle *sending* to the backend
    // based on _getAdaptiveInterval().
    _positionStream = Geolocator.getPositionStream(locationSettings: _buildLocationSettings())
        .listen((position) async {
      await _handlePositionUpdate(position);
    }, onError: (e) {
      _lastError = 'Falha no stream de localização.';
      debugPrint('Position stream error: $e');
    });
  }

  LocationSettings _buildLocationSettings() {
    final accuracy = _batteryLevel < 20 ? LocationAccuracy.medium : LocationAccuracy.high;
    const distanceFilter = 5;
    const interval = Duration(seconds: _intervalMovingSeconds);

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Rastreamento ativo',
          notificationText: 'Sua localização está sendo enviada para a entrega em andamento',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  /// Get adaptive interval based on movement and battery
  int _getAdaptiveInterval() {
    // Low battery mode
    if (_batteryLevel < 20) {
      return _intervalLowBatterySeconds;
    }

    // Check if moving or stationary
    if (_lastPosition != null) {
      final speed = _lastPosition!.speed * 3.6; // m/s to km/h
      if (speed < _stationaryThresholdKmh) {
        return _intervalStationarySeconds; // Stationary
      }
    }

    return _intervalMovingSeconds; // Moving
  }

  Future<void> _handlePositionUpdate(Position position) async {
    if (!_isTracking) return;

    try {
      final now = DateTime.now();
      final minInterval = Duration(seconds: _getAdaptiveInterval());
      final last = _lastUpdateTime;
      if (last != null && now.difference(last) < minInterval) return;

      final batteryLevel = await _battery.batteryLevel;
      final speed = position.speed * 3.6; // Convert m/s to km/h
      final isMoving = speed >= _stationaryThresholdKmh;

      final locationPoint = LocationPoint(
        id: '',
        entregaId: _currentEntregaId!,
        motoristaId: _currentMotoristaId!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: speed,
        heading: position.heading,
        altitude: position.altitude,
        batteryLevel: batteryLevel,
        isMoving: isMoving,
        createdAt: now,
      );

      if (_isOnline) {
        final success = await _sendLocationToServer(locationPoint);
        if (!success) await CacheService.addToPendingSync(locationPoint);
      } else {
        await CacheService.addToPendingSync(locationPoint);
        final pending = await CacheService.getPendingSync();
        if (pending.length > _maxPendingLocations) {
          debugPrint('⚠️ Max pending locations reached - oldest will be discarded');
        }
      }

      await CacheService.cacheLocation(locationPoint);
      _lastPosition = position;
      _lastUpdateTime = now;
      _batteryLevel = batteryLevel;
    } catch (e) {
      debugPrint('Handle position update error: $e');
    }
  }

  /// Send location to Supabase
  Future<bool> _sendLocationToServer(LocationPoint location) async {
    if (!_serverTrackingEnabled) return true;

    try {
      // Get current entrega status from entregas table
      final entregaResponse = await SupabaseConfig.client
          .from('entregas')
          .select('status')
          .eq('id', location.entregaId)
          .maybeSingle();

      final currentStatus = entregaResponse?['status'] as String? ?? 'saiu_para_entrega';

      // 1. Insert into tracking_historico (historical points)
      // We try to populate a richer schema (if columns exist). If the project schema
      // is missing some columns, we retry by dropping unknown keys.
      await _insertTrackingHistoricoSafe({
        'entrega_id': location.entregaId,
        'motorista_id': location.motoristaId,
        'status': currentStatus,
        'observacao': location.isMoving ? 'Em movimento' : 'Parado',
        'latitude': location.latitude,
        'longitude': location.longitude,
        'accuracy': location.accuracy,
        'speed': location.speed,
        'bussola_pos': _normalizeHeading(location.heading),
        'altitude': location.altitude,
        'battery_level': location.batteryLevel,
        'is_moving': location.isMoving,
        'created_at': location.createdAt.toIso8601String(),
      });

      // 2. Update localizações (current position) - upsert by motorista email
      await _updateMotoristaLocation(location);

      debugPrint('📍 Location sent: ${location.latitude}, ${location.longitude} | Speed: ${location.speed?.toStringAsFixed(1)} km/h');
      return true;
    } catch (e) {
      debugPrint('Send location to server error: $e');
      _serverTrackingEnabled = false;
      return false;
    }
  }

  /// Sync pending locations when back online
  Future<void> _syncPendingLocations() async {
    if (!_serverTrackingEnabled) return;
    try {
      final pending = await CacheService.getPendingSync();
      if (pending.isEmpty) return;

      debugPrint('🔄 Syncing ${pending.length} pending locations...');

      int synced = 0;
      for (final location in pending) {
        final success = await _sendLocationToServer(location);
        if (success) synced++;
      }

      if (synced > 0) {
        await CacheService.clearPendingSync();
        debugPrint('✅ Synced $synced locations');
      }
    } catch (e) {
      debugPrint('Sync pending locations error: $e');
    }
  }

  /// Get motorista email from database
  Future<String?> _getMotoristaEmail(String motoristaId) async {
    try {
      final response = await SupabaseConfig.client
          .from('motoristas')
          .select('email')
          .eq('id', motoristaId)
          .maybeSingle();

      return response?['email'] as String?;
    } catch (e) {
      debugPrint('Get motorista email error: $e');
      return null;
    }
  }

  /// Update motorista current location in localizações table
  Future<void> _updateMotoristaLocation(LocationPoint? location, {bool offline = false}) async {
    if (_motoristaEmail == null) return;

    try {
      if (offline) {
        // Mark motorista as offline
        await _updateLocalizacoesSafe(
          {
            'status': false,
            'visivel': false,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
          emailMotorista: _motoristaEmail!,
        );
      } else if (location != null) {
        // Upsert current location
        final data = {
          'email_motorista': _motoristaEmail!,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'precisao': location.accuracy,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': true,
          'visivel': true,
          'bussola_pos': _normalizeHeading(location.heading),
        };

        // Try to update first
        final updateResult = await _updateLocalizacoesSafe(
          data,
          emailMotorista: _motoristaEmail!,
        );

        // If no row was updated, insert new one
        if (updateResult.isEmpty) {
          await _insertLocalizacoesSafe(data);
        }
      }
    } catch (e) {
      debugPrint('Update motorista location error: $e');
    }
  }

  double? _normalizeHeading(double? heading) {
    if (heading == null) return null;
    if (heading.isNaN || !heading.isFinite) return null;
    // Geolocator can return -1 when heading is unknown.
    if (heading < 0) return null;
    // Keep within [0, 360)
    final normalized = heading % 360.0;
    return normalized;
  }

  static final RegExp _missingColumnRegex = RegExp(r"Could not find the '([^']+)' column", caseSensitive: false);

  Future<void> _insertTrackingHistoricoSafe(Map<String, dynamic> data) async {
    var payload = Map<String, dynamic>.from(data)..removeWhere((k, v) => v == null);
    for (var i = 0; i < 6; i++) {
      try {
        await SupabaseConfig.client.from('tracking_historico').insert(payload);
        return;
      } on PostgrestException catch (e) {
        final match = _missingColumnRegex.firstMatch(e.message);
        final col = match?.group(1);
        if (e.code == 'PGRST204' && col != null && payload.containsKey(col)) {
          debugPrint('tracking_historico missing column "$col". Retrying without it.');
          payload.remove(col);
          continue;
        }
        rethrow;
      }
    }
  }

  Future<List<dynamic>> _updateLocalizacoesSafe(Map<String, dynamic> data, {required String emailMotorista}) async {
    var payload = Map<String, dynamic>.from(data)..removeWhere((k, v) => v == null);
    for (var i = 0; i < 6; i++) {
      try {
        final result = await SupabaseConfig.client
            .from('localizações')
            .update(payload)
            .eq('email_motorista', emailMotorista)
            .select();
        return result as List<dynamic>;
      } on PostgrestException catch (e) {
        final match = _missingColumnRegex.firstMatch(e.message);
        final col = match?.group(1);
        if (e.code == 'PGRST204' && col != null && payload.containsKey(col)) {
          debugPrint('localizações missing column "$col". Retrying without it.');
          payload.remove(col);
          continue;
        }
        rethrow;
      }
    }
    return const [];
  }

  Future<void> _insertLocalizacoesSafe(Map<String, dynamic> data) async {
    var payload = Map<String, dynamic>.from(data)..removeWhere((k, v) => v == null);
    for (var i = 0; i < 6; i++) {
      try {
        await SupabaseConfig.client.from('localizações').insert(payload);
        return;
      } on PostgrestException catch (e) {
        final match = _missingColumnRegex.firstMatch(e.message);
        final col = match?.group(1);
        if (e.code == 'PGRST204' && col != null && payload.containsKey(col)) {
          debugPrint('localizações missing column "$col". Retrying without it.');
          payload.remove(col);
          continue;
        }
        rethrow;
      }
    }
  }

  /// Save tracking state to cache for recovery
  Future<void> _saveTrackingState() async {
    await CacheService.saveTrackingState('current_entrega_id', _currentEntregaId);
    await CacheService.saveTrackingState('current_motorista_id', _currentMotoristaId);
    await CacheService.saveTrackingState('current_session_id', _currentSessionId);
    await CacheService.saveTrackingState('is_tracking', _isTracking);
  }

  /// Restore tracking state from cache (on app restart)
  Future<void> _restoreTrackingState() async {
    try {
      final entregaId = await CacheService.getTrackingState<String>('current_entrega_id');
      final motoristaId = await CacheService.getTrackingState<String>('current_motorista_id');
      final sessionId = await CacheService.getTrackingState<String>('current_session_id');
      final wasTracking = await CacheService.getTrackingState<bool>('is_tracking') ?? false;

      if (wasTracking && entregaId != null && motoristaId != null) {
        debugPrint('🔄 Restoring tracking state for entrega $entregaId');
        _currentEntregaId = entregaId;
        _currentMotoristaId = motoristaId;
        _currentSessionId = sessionId;
        _setIsTracking(true);
        await _primeAndStartLocationUpdates();
      }
    } catch (e) {
      debugPrint('Restore tracking state error: $e');
    }
  }

  /// Clear tracking state from cache
  Future<void> _clearTrackingState() async {
    await CacheService.deleteTrackingState('current_entrega_id');
    await CacheService.deleteTrackingState('current_motorista_id');
    await CacheService.deleteTrackingState('current_session_id');
    await CacheService.deleteTrackingState('is_tracking');
  }

  /// Send local notification
  Future<void> _sendNotification(String title, String message, {String? tipo}) async {
    // Will be handled by NotificationService
    debugPrint('📬 Notification: $title - $message');
  }

  /// Dispose service
  Future<void> dispose() async {
    await stopTracking();
    _trackingTimer?.cancel();
    _positionStream?.cancel();
  }
}

enum TrackingPermissionIssueType {
  denied,
  deniedForever,
  backgroundNotAllowed,
  unknown,
}

class TrackingPermissionIssue {
  final TrackingPermissionIssueType type;
  final String message;

  const TrackingPermissionIssue({required this.type, required this.message});
}
