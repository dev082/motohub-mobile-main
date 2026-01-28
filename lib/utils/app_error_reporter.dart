import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hubfrete/models/app_user_alert.dart';
import 'package:hubfrete/services/notification_service.dart';
import 'package:hubfrete/utils/app_error_mapper.dart';

/// Central place to convert raw exceptions into friendly user notifications.
///
/// Usage:
/// `AppErrorReporter.report(context, e, operation: 'carregar entregas');`
class AppErrorReporter {
  static void report(BuildContext context, Object error, {String? operation}) {
    debugPrint('AppErrorReporter: op=$operation error=$error');

    final alert = AppErrorMapper.fromError(error, operation: operation);
    // Push in-app “banner-like” notification.
    NotificationService.instance.pushInAppAlert(alert);

    // Also show OS-level local notification (Android/iOS). On web this is a no-op.
    NotificationService.instance.showAppErrorNotification(alert);
  }
}
