import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:hubfrete/services/location_tracking_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Provides best-effort *persistent* tracking on Android using a real foreground
/// service.
///
/// Why this exists:
/// - `geolocator` can keep tracking in background, but when the user *kills* the app
///   (swipes it away), many devices/OEMs stop the Dart isolate.
/// - A foreground service is the most reliable way to keep the tracker alive.
///
/// Notes:
/// - iOS does **not** allow running after the user force-quits the app.
/// - This service is only started when a delivery tracking session is active.
class PersistentBackgroundTrackingService {
  static final PersistentBackgroundTrackingService instance = PersistentBackgroundTrackingService._();
  PersistentBackgroundTrackingService._();

  static const int _notificationId = 22101;

  bool _configured = false;

  Future<void> ensureConfigured() async {
    if (_configured) return;
    if (kIsWeb) return;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        initialNotificationTitle: 'Rastreamento ativo',
        initialNotificationContent: 'Enviando localização em tempo real',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: _onStart,
        // iOS background fetch is not suitable for true realtime tracking.
        // We keep this disabled.
        onBackground: _onIosBackground,
      ),
    );

    _configured = true;
  }

  Future<bool> isRunning() async {
    if (kIsWeb) return false;
    return FlutterBackgroundService().isRunning();
  }

  /// Starts the foreground service and tells it to start tracking.
  Future<void> start({required String entregaId, required String motoristaId}) async {
    if (kIsWeb) return;
    await ensureConfigured();

    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    }
    service.invoke('startTracking', {'entregaId': entregaId, 'motoristaId': motoristaId});
  }

  /// Stops tracking and (on Android) stops the foreground service.
  Future<void> stop() async {
    if (kIsWeb) return;
    await ensureConfigured();

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopTracking');
      // Give the isolate a moment to persist “offline” to backend before stopping.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async => true;

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    // Supabase must be available in this isolate for DB writes.
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Background tracking: Supabase init error: $e');
  }

  try {
    await LocationTrackingService.instance.init();
  } catch (e) {
    debugPrint('Background tracking: LocationTrackingService init error: $e');
  }

  if (service is AndroidServiceInstance) {
    // Ensure foreground mode and a persistent notification.
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'Rastreamento ativo',
      content: 'Enviando localização em tempo real',
    );
  }

  // Commands from the UI isolate.
  service.on('startTracking').listen((event) async {
    try {
      final entregaId = (event?['entregaId'] as String?)?.trim();
      final motoristaId = (event?['motoristaId'] as String?)?.trim();
      if (entregaId == null || entregaId.isEmpty || motoristaId == null || motoristaId.isEmpty) {
        debugPrint('Background tracking: startTracking missing entregaId/motoristaId');
        return;
      }
      await LocationTrackingService.instance.startTrackingFromBackground(entregaId, motoristaId);
    } catch (e) {
      debugPrint('Background tracking: startTracking error: $e');
    }
  });

  service.on('stopTracking').listen((event) async {
    try {
      await LocationTrackingService.instance.stopTracking(stopPersistentService: false);
    } catch (e) {
      debugPrint('Background tracking: stopTracking error: $e');
    }
  });

  service.on('stopService').listen((event) async {
    try {
      await LocationTrackingService.instance.stopTracking(stopPersistentService: false);
    } catch (e) {
      debugPrint('Background tracking: stopService error: $e');
    }
    service.stopSelf();
  });
}
