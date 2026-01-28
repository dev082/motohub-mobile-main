import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hubfrete/models/app_user_alert.dart';
import 'package:hubfrete/supabase/supabase_config.dart';

/// Local notifications helper with multiple channels support.
///
/// Note: On web this is intentionally a no-op.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // In-app “push-like” alert.
  // We keep it here (instead of Provider) so any layer can raise an alert.
  final ValueNotifier<AppUserAlert?> _activeInAppAlert = ValueNotifier<AppUserAlert?>(null);
  ValueListenable<AppUserAlert?> get activeInAppAlertListenable => _activeInAppAlert;
  AppUserAlert? get activeInAppAlert => _activeInAppAlert.value;

  // Notification channels
  static const String _chatChannelId = 'chat_messages';
  static const String _chatChannelName = 'Mensagens do chat';
  static const String _chatChannelDescription = 'Notificações quando chegam novas mensagens.';

  static const String _trackingChannelId = 'tracking_updates';
  static const String _trackingChannelName = 'Atualizações de Rastreamento';
  static const String _trackingChannelDescription = 'Notificações sobre status de entregas e rastreamento.';

  static const String _alertChannelId = 'alerts';
  static const String _alertChannelName = 'Alertas';
  static const String _alertChannelDescription = 'Alertas importantes sobre entregas e rotas.';

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _plugin.initialize(initSettings);

      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      // Create notification channels (Android)
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: _chatChannelDescription,
        importance: Importance.high,
      ));

      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _trackingChannelId,
        _trackingChannelName,
        description: _trackingChannelDescription,
        importance: Importance.high,
        playSound: true,
      ));

      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: _alertChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.init error: $e');
      _initialized = true; // Avoid repeated init attempts.
    }
  }

  Future<void> showChatMessage({
    required String cargaCodigo,
    required String senderNome,
    required String message,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      final title = 'Nova mensagem • Carga $cargaCodigo';
      final body = '$senderNome: $message';

      const androidDetails = AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('NotificationService.showChatMessage error: $e');
    }
  }

  /// Show tracking notification (status updates, ETA, etc.)
  Future<void> showTrackingNotification({
    required String title,
    required String message,
    String? entregaId,
    String? motoristaId,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _trackingChannelId,
        _trackingChannelName,
        channelDescription: _trackingChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
      await _plugin.show(id, title, message, details);

      // Log to database
      if (entregaId != null) {
        await _logNotification(
          entregaId: entregaId,
          motoristaId: motoristaId,
          tipo: 'status_change',
          titulo: title,
          mensagem: message,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.showTrackingNotification error: $e');
    }
  }

  /// Show alert notification (route deviation, low battery, offline, etc.)
  Future<void> showAlertNotification({
    required String title,
    required String message,
    required String tipo,
    String? entregaId,
    String? motoristaId,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
      await _plugin.show(id, '🚨 $title', message, details);

      // Log to database
      if (entregaId != null) {
        await _logNotification(
          entregaId: entregaId,
          motoristaId: motoristaId,
          tipo: tipo,
          titulo: title,
          mensagem: message,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.showAlertNotification error: $e');
    }
  }

  /// OS-level local notification for app errors (network/auth/permissions).
  ///
  /// This complements the in-app overlay so the user gets a clear signal.
  Future<void> showAppErrorNotification(AppUserAlert alert) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
      await _plugin.show(id, alert.title, alert.message, details);
    } catch (e) {
      debugPrint('NotificationService.showAppErrorNotification error: $e');
    }
  }

  void pushInAppAlert(AppUserAlert alert) {
    final current = _activeInAppAlert.value;
    if (current != null && current.code == alert.code && current.message == alert.message) return;
    _activeInAppAlert.value = alert;
  }

  void dismissInAppAlert() {
    _activeInAppAlert.value = null;
  }

  /// Show delivery event notification (pickup started, arrived, completed, etc.)
  Future<void> showDeliveryEvent({
    required String title,
    required String message,
    required String tipo,
    String? entregaId,
    String? motoristaId,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _trackingChannelId,
        _trackingChannelName,
        channelDescription: _trackingChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
      await _plugin.show(id, title, message, details);

      // Log to database
      if (entregaId != null) {
        await _logNotification(
          entregaId: entregaId,
          motoristaId: motoristaId,
          tipo: tipo,
          titulo: title,
          mensagem: message,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.showDeliveryEvent error: $e');
    }
  }

  /// Log notification to database
  Future<void> _logNotification({
    required String entregaId,
    String? motoristaId,
    required String tipo,
    required String titulo,
    required String mensagem,
    Map<String, dynamic>? dados,
  }) async {
    try {
      await SupabaseConfig.client.from('notifications_log').insert({
        'entrega_id': entregaId,
        'motorista_id': motoristaId,
        'tipo': tipo,
        'titulo': titulo,
        'mensagem': mensagem,
        'dados': dados ?? {},
        'enviada_em': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Log notification error: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Cancel all notifications error: $e');
    }
  }

  /// Cancel specific notification
  Future<void> cancel(int id) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('Cancel notification error: $e');
    }
  }
}
