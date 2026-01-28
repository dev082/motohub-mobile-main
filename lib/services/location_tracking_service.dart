import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hubfrete/models/location_point.dart';
import 'package:hubfrete/models/tracking_session.dart';
import 'package:hubfrete/services/cache_service.dart';
import 'package:hubfrete/services/persistent_background_tracking_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

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
  Timer? _heartbeatTimer;
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

  int _consecutiveServerErrors = 0;
  DateTime? _nextServerAttemptAt;

  // Server uses "tracking_historico" for location history and "localizações" for current position.
  bool _serverTrackingEnabled = true;
  String? _motoristaEmail;
  
  // Adaptive interval settings
  static const int _intervalMovingSeconds = 5; // 5s when moving
  static const int _intervalStationarySeconds = 30; // 30s when stationary
  static const int _intervalLowBatterySeconds = 60; // 60s when battery < 20%
  static const double _stationaryThresholdKmh = 5.0; // < 5 km/h = stationary
  static const int _maxPendingLocations = 100; // Max locations to queue offline

  // Business requirement: whenever we receive a GPS update, we persist it both as
  // "current location" and as an historical point.
  static const bool _writeHistoricoEveryUpdate = true;

  // Heartbeat: even when the device is stopped (or the stream pauses), we keep the
  // "current location" row fresh so the backend/UI does not mark the driver as offline.
  static const Duration _heartbeatInterval = Duration(seconds: 15);

  bool get isTracking => _isTracking;
  String? get currentSessionId => _currentSessionId;
  String? get currentEntregaId => _currentEntregaId;
  String? get lastError => _lastError;
  bool get isOnline => _isOnline;
  int get consecutiveServerErrors => _consecutiveServerErrors;
  DateTime? get nextServerAttemptAt => _nextServerAttemptAt;

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
      // connectivity_plus can be noisy (especially on iOS). We only consider
      // explicit "none" as offline; otherwise we keep attempting.
      _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      
      if (!wasOnline && _isOnline) {
        debugPrint('Device back online - syncing pending locations');
        _syncPendingLocations();
      }

      if (wasOnline != _isOnline) {
        debugPrint('Connectivity changed. isOnline=$_isOnline results=$results');
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

      // Android: request ignoring battery optimizations for reliable background tracking.
      // Many OEMs will kill background location unless the app is whitelisted.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && requireAlways) {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (!status.isGranted) {
          final req = await Permission.ignoreBatteryOptimizations.request();
          debugPrint('Ignore battery optimizations permission: $req');
          final after = await Permission.ignoreBatteryOptimizations.status;
          if (!after.isGranted) {
            _lastError = 'Para manter o rastreador com a tela desligada, permita "Ignorar otimizações de bateria".';
            permissionIssueNotifier.value = TrackingPermissionIssue(
              type: TrackingPermissionIssueType.batteryOptimization,
              message: _lastError!,
            );
            // We still return true because tracking may work on some devices,
            // but we notify UI so user can fix reliability.
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
    return _startTrackingInternal(
      entregaId: entregaId,
      motoristaId: motoristaId,
      enforcePermissions: true,
      startPersistentServiceOnAndroid: true,
      sendUserNotification: true,
    );
  }

  /// Entry-point used by the Android foreground service isolate.
  ///
  /// Important: we must NOT trigger permission prompts from a background isolate.
  Future<bool> startTrackingFromBackground(String entregaId, String motoristaId) async {
    return _startTrackingInternal(
      entregaId: entregaId,
      motoristaId: motoristaId,
      enforcePermissions: false,
      startPersistentServiceOnAndroid: false,
      sendUserNotification: false,
    );
  }

  Future<bool> _startTrackingInternal({
    required String entregaId,
    required String motoristaId,
    required bool enforcePermissions,
    required bool startPersistentServiceOnAndroid,
    required bool sendUserNotification,
  }) async {
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

      if (enforcePermissions) {
        // Business rule: if a driver has an active entrega, we must be able to track in background.
        final hasPermission = await checkPermissions(requireAlways: true);
        if (!hasPermission) {
          debugPrint('No location permission - cannot start tracking. lastError=$_lastError');
          return false;
        }
      }

      // Get motorista email (used to upsert current location + offline marker)
      final motorista = await _getMotoristaEmail(motoristaId);
      if (motorista == null) {
        _lastError = 'Não foi possível obter o email do motorista.';
        debugPrint('Failed to get motorista email');
        return false;
      }
      _motoristaEmail = motorista;

      // Stop any existing tracking in this isolate
      await stopTracking();

      // Set tracking state
      _currentEntregaId = entregaId;
      _currentMotoristaId = motoristaId;
      _currentSessionId = 'tracking-$entregaId-${DateTime.now().millisecondsSinceEpoch}';

      // Save state to cache for recovery
      await _saveTrackingState();

      // Android: prefer the real foreground service for persistence (survives task removal).
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        _setIsTracking(true);
        if (startPersistentServiceOnAndroid) {
          unawaited(PersistentBackgroundTrackingService.instance.start(entregaId: entregaId, motoristaId: motoristaId));
          debugPrint('✅ Tracking delegated to Android foreground service');
          if (sendUserNotification) {
            await _sendNotification('Rastreamento Iniciado', 'Sua localização está sendo compartilhada em tempo real', tipo: 'coleta_iniciada');
          }
          return true;
        }
      }

      // iOS / other platforms: run tracking in-app (background location mode is handled by OS).
      _setIsTracking(true);
      await _primeAndStartLocationUpdates();

      debugPrint('✅ Tracking started for entrega $entregaId');
      if (sendUserNotification) {
        await _sendNotification('Rastreamento Iniciado', 'Sua localização está sendo compartilhada em tempo real', tipo: 'coleta_iniciada');
      }

      return true;
    } catch (e) {
      _lastError = 'Erro ao iniciar rastreamento: $e';
      debugPrint('Start tracking error: $e');
      _setIsTracking(false);
      return false;
    }
  }

  /// Stop tracking
  Future<void> stopTracking({bool stopPersistentService = true}) async {
    if (!_isTracking) return;

    try {
      debugPrint('➡️ stopTracking(session=$_currentSessionId)');

      if (stopPersistentService && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        unawaited(PersistentBackgroundTrackingService.instance.stop());
      }

      _trackingTimer?.cancel();
      _heartbeatTimer?.cancel();
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
    _heartbeatTimer?.cancel();
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

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      try {
        if (!_isTracking) return;
        final p = _lastPosition;
        if (p == null) return;
        await _sendHeartbeat(p);
      } catch (e) {
        debugPrint('Heartbeat error: $e');
      }
    });
  }

  Future<void> _sendHeartbeat(Position position) async {
    // Only updates the "current" location row (localizações) and keeps a fresh timestamp.
    // This prevents the backend/client from marking the driver as offline when stationary.
    if (_currentEntregaId == null || _currentMotoristaId == null) return;

    final now = DateTime.now();
    final batteryLevel = await _battery.batteryLevel;
    final speed = _speedKmhFromPosition(position, now: now);
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

    final canAttemptServer = _isOnline && (_nextServerAttemptAt == null || now.isAfter(_nextServerAttemptAt!));
    if (!canAttemptServer) return;

    try {
      await _updateMotoristaLocation(locationPoint);
    } catch (e) {
      debugPrint('Heartbeat server update error: $e');
    }
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
      final speed = _speedKmhFromPosition(_lastPosition!, now: DateTime.now());
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
      final batteryLevel = await _battery.batteryLevel;
      final speed = _speedKmhFromPosition(
        position,
        now: now,
        lastPosition: _lastPosition,
        lastTime: _lastUpdateTime,
      );
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

      // Near real-time: always try to refresh the "current location" row.
      // This is what dashboards/maps typically read.
      final canAttemptServer = _isOnline && (_nextServerAttemptAt == null || now.isAfter(_nextServerAttemptAt!));
      if (canAttemptServer) {
        try {
          await _updateMotoristaLocation(locationPoint);
        } catch (e) {
          debugPrint('Realtime current location update error: $e');
        }
      }

      // Persist the historical point. By default we write on every GPS update (true real-time).
      // If needed in the future, this can be reverted to adaptive interval to reduce database writes.
      final shouldWriteHistorico = _writeHistoricoEveryUpdate;

      if (shouldWriteHistorico) {
        if (canAttemptServer) {
          final success = await _sendLocationToServer(locationPoint);
          if (!success) {
            await CacheService.addToPendingSync(locationPoint);
          } else {
            unawaited(_syncPendingLocations());
          }
        } else {
          await CacheService.addToPendingSync(locationPoint);
          final pendingCount = (await CacheService.getCacheStats())['pending_sync'] ?? 0;
          if (pendingCount > _maxPendingLocations) {
            debugPrint('⚠️ Max pending locations reached ($pendingCount) - oldest may be discarded by storage');
          }
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

  double _speedKmhFromPosition(
    Position position, {
    required DateTime now,
    Position? lastPosition,
    DateTime? lastTime,
  }) {
    // 1) Prefer GPS-provided speed (m/s -> km/h)
    final raw = position.speed;
    if (raw.isFinite && raw >= 0) {
      return raw * 3.6;
    }

    // 2) Fallback: compute from distance between points
    if (lastPosition != null && lastTime != null) {
      final dt = now.difference(lastTime).inSeconds;
      if (dt > 0) {
        final distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          position.latitude,
          position.longitude,
        );
        final speed = (distance / dt) * 3.6;
        if (speed.isFinite && speed >= 0) return speed;
      }
    }

    return 0;
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

      final currentStatus = _sanitizeStatusEntrega(entregaResponse?['status'] as String?);

      // Update localizações (current position) - upsert by motorista email.
      // A database trigger will automatically sync this to tracking_historico.
      await _updateMotoristaLocation(location, statusEntrega: currentStatus);

      debugPrint('📍 Location sent: ${location.latitude}, ${location.longitude} | Speed: ${location.speed?.toStringAsFixed(1)} km/h');
      _consecutiveServerErrors = 0;
      _nextServerAttemptAt = null;
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Send location to server PostgrestException: code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
      // Do NOT permanently disable server tracking on transient errors.
      _consecutiveServerErrors++;
      final backoffSeconds = switch (_consecutiveServerErrors) {
        1 => 2,
        2 => 5,
        3 => 10,
        4 => 20,
        _ => 30,
      };
      _nextServerAttemptAt = DateTime.now().add(Duration(seconds: backoffSeconds));
      debugPrint('Server send failed (#$_consecutiveServerErrors). Next attempt after ${_nextServerAttemptAt!.toIso8601String()}');
      return false;
    } catch (e) {
      debugPrint('Send location to server error: $e');
      _consecutiveServerErrors++;
      final backoffSeconds = switch (_consecutiveServerErrors) {
        1 => 2,
        2 => 5,
        3 => 10,
        4 => 20,
        _ => 30,
      };
      _nextServerAttemptAt = DateTime.now().add(Duration(seconds: backoffSeconds));
      debugPrint('Server send failed (#$_consecutiveServerErrors). Next attempt after ${_nextServerAttemptAt!.toIso8601String()}');
      return false;
    }
  }

  /// Sync pending locations when back online
  Future<void> _syncPendingLocations() async {
    if (!_serverTrackingEnabled) return;
    try {
      final entries = await CacheService.getPendingSyncEntries();
      if (entries.isEmpty) return;

      debugPrint('🔄 Syncing ${entries.length} pending locations...');

      var synced = 0;
      for (final entry in entries.entries) {
        final success = await _sendLocationToServer(entry.value);
        if (success) {
          synced++;
          await CacheService.removePendingLocation(entry.key);
        } else {
          // Respect backoff: stop trying more items until next window.
          break;
        }
      }

      if (synced > 0) debugPrint('✅ Synced $synced pending locations');
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

  /// Update motorista current location in localizações table.
  /// The database trigger will automatically sync this to tracking_historico.
  Future<void> _updateMotoristaLocation(LocationPoint? location, {bool offline = false, String? statusEntrega}) async {
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
        // Upsert current location.
        // IMPORTANT: Keep this aligned with the current DB schema (see lib/supabase/database.types.ts).
        // Table public."localizações" columns available today:
        // - email_motorista, latitude, longitude, precisao, bussola_pos, velocidade, status, visivel, timestamp
        final data = <String, dynamic>{
          'email_motorista': _motoristaEmail!,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'precisao': location.accuracy,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': true,
          'visivel': true,
          'bussola_pos': _normalizeHeading(location.heading),
          // velocidade is stored in km/h in our app logic.
          'velocidade': location.speed,
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

  static const Set<String> _validStatusEntrega = {
    'aguardando',
    'saiu_para_coleta',
    'saiu_para_entrega',
    'entregue',
    'problema',
    'cancelada',
  };

  String _sanitizeStatusEntrega(String? statusFromDb) {
    final s = (statusFromDb ?? '').trim();
    if (_validStatusEntrega.contains(s)) return s;
    return 'saiu_para_entrega';
  }

  static final RegExp _missingColumnRegex = RegExp(r"Could not find the '([^']+)' column", caseSensitive: false);

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

        // Android: ensure the foreground service is running (most persistent option).
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          _setIsTracking(true);
          unawaited(PersistentBackgroundTrackingService.instance.start(entregaId: entregaId, motoristaId: motoristaId));
          return;
        }

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
    _heartbeatTimer?.cancel();
    _positionStream?.cancel();
  }
}

enum TrackingPermissionIssueType {
  denied,
  deniedForever,
  backgroundNotAllowed,
  batteryOptimization,
  unknown,
}

class TrackingPermissionIssue {
  final TrackingPermissionIssueType type;
  final String message;

  const TrackingPermissionIssue({required this.type, required this.message});
}
