import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:motohub/models/location_point.dart';
import 'package:motohub/models/tracking_session.dart';
import 'package:motohub/services/cache_service.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:permission_handler/permission_handler.dart';

/// Advanced location tracking service with adaptive intervals and battery optimization
class LocationTrackingService {
  static final LocationTrackingService instance = LocationTrackingService._();
  LocationTrackingService._();

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
  
  // Adaptive interval settings
  static const int _intervalMovingSeconds = 5; // 5s when moving
  static const int _intervalStationarySeconds = 30; // 30s when stationary
  static const int _intervalLowBatterySeconds = 60; // 60s when battery < 20%
  static const double _stationaryThresholdKmh = 5.0; // < 5 km/h = stationary
  static const int _maxPendingLocations = 100; // Max locations to queue offline

  bool get isTracking => _isTracking;
  String? get currentSessionId => _currentSessionId;

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

  /// Check and request permissions
  Future<bool> checkPermissions() async {
    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled');
        return false;
      }

      // Check location permission
      var permission = await Permission.location.status;
      if (permission.isDenied) {
        permission = await Permission.location.request();
      }

      if (permission.isPermanentlyDenied) {
        debugPrint('Location permission permanently denied');
        await openAppSettings();
        return false;
      }

      // Request background location (Android)
      if (!kIsWeb && permission.isGranted) {
        var bgPermission = await Permission.locationAlways.status;
        if (bgPermission.isDenied) {
          bgPermission = await Permission.locationAlways.request();
        }
      }

      return permission.isGranted;
    } catch (e) {
      debugPrint('Check permissions error: $e');
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
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        debugPrint('No location permission - cannot start tracking');
        return false;
      }

      // Stop any existing tracking
      await stopTracking();

      // Create tracking session
      _currentEntregaId = entregaId;
      _currentMotoristaId = motoristaId;
      _currentSessionId = await _createTrackingSession(entregaId, motoristaId);
      
      if (_currentSessionId == null) {
        debugPrint('Failed to create tracking session');
        return false;
      }

      // Save state to cache for recovery
      await _saveTrackingState();

      // Start location updates with adaptive interval
      _isTracking = true;
      _startLocationUpdates();

      debugPrint('✅ Tracking started for entrega $entregaId');
      await _sendNotification(
        'Rastreamento Iniciado',
        'Sua localização está sendo compartilhada em tempo real',
        tipo: 'coleta_iniciada',
      );

      return true;
    } catch (e) {
      debugPrint('Start tracking error: $e');
      _isTracking = false;
      return false;
    }
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      _trackingTimer?.cancel();
      _positionStream?.cancel();
      
      // Complete tracking session
      if (_currentSessionId != null) {
        await _completeTrackingSession(_currentSessionId!);
      }

      // Clear state
      await _clearTrackingState();
      
      _isTracking = false;
      _currentEntregaId = null;
      _currentMotoristaId = null;
      _currentSessionId = null;
      _lastPosition = null;
      _lastUpdateTime = null;

      debugPrint('🛑 Tracking stopped');
    } catch (e) {
      debugPrint('Stop tracking error: $e');
    }
  }

  /// Start location updates with adaptive interval
  void _startLocationUpdates() {
    // Use timer for adaptive interval control
    _trackingTimer = Timer.periodic(Duration(seconds: _getAdaptiveInterval()), (timer) async {
      await _updateLocation();
      
      // Adjust interval dynamically
      timer.cancel();
      _trackingTimer = Timer.periodic(Duration(seconds: _getAdaptiveInterval()), (t) => _updateLocation());
    });

    // Initial update
    _updateLocation();
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

  /// Update location and send to server
  Future<void> _updateLocation() async {
    if (!_isTracking) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _batteryLevel < 20 ? LocationAccuracy.medium : LocationAccuracy.high,
          distanceFilter: 10, // Minimum 10m movement
        ),
      ).timeout(const Duration(seconds: 10));

      final batteryLevel = await _battery.batteryLevel;
      final speed = position.speed * 3.6; // Convert m/s to km/h
      final isMoving = speed >= _stationaryThresholdKmh;

      final locationPoint = LocationPoint(
        id: '', // Will be assigned by server
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
        createdAt: DateTime.now(),
      );

      // Try to send to server if online
      if (_isOnline) {
        final success = await _sendLocationToServer(locationPoint);
        if (!success) {
          // Queue for later sync if failed
          await CacheService.addToPendingSync(locationPoint);
        }
      } else {
        // Offline - add to pending sync queue
        await CacheService.addToPendingSync(locationPoint);
        
        // Check queue size
        final pending = await CacheService.getPendingSync();
        if (pending.length > _maxPendingLocations) {
          debugPrint('⚠️ Max pending locations reached - oldest will be discarded');
        }
      }

      // Cache locally
      await CacheService.cacheLocation(locationPoint);
      
      _lastPosition = position;
      _lastUpdateTime = DateTime.now();
      _batteryLevel = batteryLevel;

    } catch (e) {
      debugPrint('Update location error: $e');
    }
  }

  /// Send location to Supabase
  Future<bool> _sendLocationToServer(LocationPoint location) async {
    try {
      final response = await SupabaseConfig.client
          .from('locations')
          .insert(location.toJson()..remove('id'))
          .select()
          .single();

      debugPrint('📍 Location sent: ${location.latitude}, ${location.longitude} | Speed: ${location.speed?.toStringAsFixed(1)} km/h');
      return true;
    } catch (e) {
      debugPrint('Send location to server error: $e');
      return false;
    }
  }

  /// Sync pending locations when back online
  Future<void> _syncPendingLocations() async {
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

  /// Create tracking session in database
  Future<String?> _createTrackingSession(String entregaId, String motoristaId) async {
    try {
      final response = await SupabaseConfig.client
          .from('tracking_sessions')
          .insert({
            'entrega_id': entregaId,
            'motorista_id': motoristaId,
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response['id'] as String;
    } catch (e) {
      debugPrint('Create tracking session error: $e');
      return null;
    }
  }

  /// Complete tracking session
  Future<void> _completeTrackingSession(String sessionId) async {
    try {
      await SupabaseConfig.client
          .from('tracking_sessions')
          .update({
            'status': 'completed',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      debugPrint('Tracking session completed: $sessionId');
    } catch (e) {
      debugPrint('Complete tracking session error: $e');
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
        _isTracking = true;
        _startLocationUpdates();
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
