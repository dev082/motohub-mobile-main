import 'package:flutter/material.dart';

enum AppUserAlertSeverity { info, warning, error }

/// Represents an in-app “push-like” alert that the UI can show globally.
///
/// This is used to present friendly messages to end users when low-level
/// technical errors happen (network, auth, permissions, etc.).
class AppUserAlert {
  final String id;
  final AppUserAlertSeverity severity;

  /// Stable machine-friendly code (useful for support).
  final String code;

  /// Short friendly title.
  final String title;

  /// Friendly message with what happened.
  final String message;

  /// Optional extra details (e.g. raw exception) used in the “details” sheet.
  final String? technicalDetails;

  /// Suggested user steps. Shown when user taps the action.
  final List<String> steps;

  /// Primary CTA label.
  final String actionLabel;

  /// Determines what the action button does.
  final AppUserAlertAction action;

  /// Optional payload for action.
  final Map<String, dynamic> actionData;

  final DateTime createdAt;

  const AppUserAlert({
    required this.id,
    required this.severity,
    required this.code,
    required this.title,
    required this.message,
    required this.steps,
    required this.actionLabel,
    required this.action,
    this.actionData = const {},
    this.technicalDetails,
    required this.createdAt,
  });

  Color severityColor(ColorScheme scheme) {
    switch (severity) {
      case AppUserAlertSeverity.info:
        return scheme.primary;
      case AppUserAlertSeverity.warning:
        return scheme.tertiary;
      case AppUserAlertSeverity.error:
        return scheme.error;
    }
  }

  IconData severityIcon() {
    switch (severity) {
      case AppUserAlertSeverity.info:
        return Icons.info_outline;
      case AppUserAlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AppUserAlertSeverity.error:
        return Icons.error_outline;
    }
  }
}

enum AppUserAlertAction {
  /// Opens a bottom sheet with steps and a “copy details” button.
  showFixSteps,

  /// Signs out and navigates to login.
  relogin,
}
