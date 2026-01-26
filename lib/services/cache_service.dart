import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:motohub/models/location_point.dart';

/// Offline-first cache service using Hive
class CacheService {
  static const String _locationsCachebox = 'locations_cache';
  static const String _pendingLocationsSyncBox = 'pending_locations_sync';
  static const String _trackingStateBox = 'tracking_state';

  static Box<Map>? _locationsBox;
  static Box<Map>? _pendingSyncBox;
  static Box? _stateBox;
  static bool _initialized = false;

  // Some web/embedded environments (like sandboxed iframes) may not support
  // IndexedDB. Hive will throw at init/openBox. In that case, we fall back to
  // an in-memory store so the app keeps working.
  static bool _useMemoryStore = false;
  static final Map<String, Map<String, dynamic>> _locationsMem = {};
  static final Map<String, Map<String, dynamic>> _pendingSyncMem = {};
  static final Map<String, dynamic> _stateMem = {};

  /// Initialize Hive and open boxes
  static Future<void> init() async {
    if (_initialized) return;

    // In Dreamflow's web preview (and some sandboxed/embedded web environments),
    // IndexedDB can be unavailable which makes Hive throw with cryptic JS errors.
    // For web we default to an in-memory cache to keep the app stable.
    if (kIsWeb) {
      _useMemoryStore = true;
      _initialized = true;
      debugPrint('CacheService: running on web, using in-memory cache');
      return;
    }

    try {
      await Hive.initFlutter();

      _locationsBox = await Hive.openBox<Map>(_locationsCachebox);
      _pendingSyncBox = await Hive.openBox<Map>(_pendingLocationsSyncBox);
      _stateBox = await Hive.openBox(_trackingStateBox);

      _initialized = true;
      _useMemoryStore = false;
      debugPrint('CacheService initialized successfully');
    } catch (e, st) {
      // Fallback for environments without IndexedDB / filesystem.
      _useMemoryStore = true;
      _initialized = true; // Avoid infinite retry
      debugPrint('CacheService init error (fallback to memory): $e');
      debugPrint('CacheService init stack: $st');
    }
  }

  /// Cache location point locally
  static Future<void> cacheLocation(LocationPoint location) async {
    if (!_initialized) await init();
    try {
      final json = location.toJson();
      if (_useMemoryStore) {
        _locationsMem[location.id] = Map<String, dynamic>.from(json);
        return;
      }
      await _locationsBox?.put(location.id, json);
    } catch (e) {
      debugPrint('Cache location error: $e');
    }
  }

  /// Add location to pending sync queue (offline mode)
  static Future<void> addToPendingSync(LocationPoint location) async {
    if (!_initialized) await init();
    try {
      final key = '${location.entregaId}_${DateTime.now().millisecondsSinceEpoch}';
      final json = location.toJson();
      if (_useMemoryStore) {
        _pendingSyncMem[key] = Map<String, dynamic>.from(json);
      } else {
        await _pendingSyncBox?.put(key, json);
      }
      debugPrint('Added location to pending sync queue: $key');
    } catch (e) {
      debugPrint('Add to pending sync error: $e');
    }
  }

  /// Get all pending locations to sync
  static Future<List<LocationPoint>> getPendingSync() async {
    if (!_initialized) await init();
    try {
      final items = _useMemoryStore
          ? _pendingSyncMem.values.toList()
          : (_pendingSyncBox?.values.toList() ?? []);
      return items.map((json) => LocationPoint.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      debugPrint('Get pending sync error: $e');
      return [];
    }
  }

  /// Clear pending sync queue after successful upload
  static Future<void> clearPendingSync() async {
    if (!_initialized) await init();
    try {
      if (_useMemoryStore) {
        _pendingSyncMem.clear();
      } else {
        await _pendingSyncBox?.clear();
      }
      debugPrint('Cleared pending sync queue');
    } catch (e) {
      debugPrint('Clear pending sync error: $e');
    }
  }

  /// Remove specific pending location after successful sync
  static Future<void> removePendingLocation(String key) async {
    if (!_initialized) await init();
    try {
      if (_useMemoryStore) {
        _pendingSyncMem.remove(key);
      } else {
        await _pendingSyncBox?.delete(key);
      }
    } catch (e) {
      debugPrint('Remove pending location error: $e');
    }
  }

  /// Get cached locations for an entrega
  static Future<List<LocationPoint>> getCachedLocations(String entregaId, {int limit = 100}) async {
    if (!_initialized) await init();
    try {
      final allLocations = _useMemoryStore ? _locationsMem.values.toList() : (_locationsBox?.values.toList() ?? []);
      final filtered = allLocations
          .map((json) => LocationPoint.fromJson(Map<String, dynamic>.from(json)))
          .where((loc) => loc.entregaId == entregaId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return filtered.take(limit).toList();
    } catch (e) {
      debugPrint('Get cached locations error: $e');
      return [];
    }
  }

  /// Save tracking state (active session info)
  static Future<void> saveTrackingState(String key, dynamic value) async {
    if (!_initialized) await init();
    try {
      if (_useMemoryStore) {
        _stateMem[key] = value;
      } else {
        await _stateBox?.put(key, value);
      }
    } catch (e) {
      debugPrint('Save tracking state error: $e');
    }
  }

  /// Get tracking state
  static Future<T?> getTrackingState<T>(String key) async {
    if (!_initialized) await init();
    try {
      if (_useMemoryStore) return _stateMem[key] as T?;
      return _stateBox?.get(key) as T?;
    } catch (e) {
      debugPrint('Get tracking state error: $e');
      return null;
    }
  }

  /// Delete tracking state
  static Future<void> deleteTrackingState(String key) async {
    if (!_initialized) await init();
    try {
      if (_useMemoryStore) {
        _stateMem.remove(key);
      } else {
        await _stateBox?.delete(key);
      }
    } catch (e) {
      debugPrint('Delete tracking state error: $e');
    }
  }

  /// Clear all cache (use with caution)
  static Future<void> clearAll() async {
    if (!_initialized) await init();
    try {
      if (_useMemoryStore) {
        _locationsMem.clear();
        _pendingSyncMem.clear();
        _stateMem.clear();
      } else {
        await _locationsBox?.clear();
        await _pendingSyncBox?.clear();
        await _stateBox?.clear();
      }
      debugPrint('Cleared all cache');
    } catch (e) {
      debugPrint('Clear all cache error: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, int>> getCacheStats() async {
    if (!_initialized) await init();
    return {
      'cached_locations': _useMemoryStore ? _locationsMem.length : (_locationsBox?.length ?? 0),
      'pending_sync': _useMemoryStore ? _pendingSyncMem.length : (_pendingSyncBox?.length ?? 0),
      'state_keys': _useMemoryStore ? _stateMem.length : (_stateBox?.length ?? 0),
    };
  }

  /// Close all boxes (call on app dispose)
  static Future<void> close() async {
    try {
      if (_useMemoryStore) {
        _locationsMem.clear();
        _pendingSyncMem.clear();
        _stateMem.clear();
      } else {
        await _locationsBox?.close();
        await _pendingSyncBox?.close();
        await _stateBox?.close();
      }
      _initialized = false;
      debugPrint('CacheService closed');
    } catch (e) {
      debugPrint('CacheService close error: $e');
    }
  }
}
