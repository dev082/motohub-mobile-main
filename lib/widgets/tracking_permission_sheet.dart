import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hubfrete/services/location_tracking_service.dart';

/// Hosts a bottom-sheet prompt asking the user to enable background location.
///
/// This widget listens to [LocationTrackingService.permissionIssueNotifier] and,
/// when an issue is emitted, it shows a modern modal bottom sheet with a CTA
/// that opens the app settings.
class TrackingPermissionPromptHost extends StatefulWidget {
  const TrackingPermissionPromptHost({super.key, required this.child});

  final Widget child;

  @override
  State<TrackingPermissionPromptHost> createState() => _TrackingPermissionPromptHostState();
}

class _TrackingPermissionPromptHostState extends State<TrackingPermissionPromptHost> {
  TrackingPermissionIssueType? _lastShownType;
  DateTime? _lastShownAt;

  bool get _canShowAgain {
    final last = _lastShownAt;
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(seconds: 20);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TrackingPermissionIssue?>(
      valueListenable: LocationTrackingService.instance.permissionIssueNotifier,
      builder: (context, issue, _) {
        if (issue != null) {
          final shouldShow = (_lastShownType != issue.type) || _canShowAgain;
          if (shouldShow) {
            _lastShownType = issue.type;
            _lastShownAt = DateTime.now();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _showSheet(context, issue);
            });
          }
        }

        return widget.child;
      },
    );
  }

  Future<void> _showSheet(BuildContext context, TrackingPermissionIssue issue) async {
    // If another sheet is already open, avoid stacking.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TrackingPermissionSheet(issue: issue),
    );

    // Clear after user dismisses so we can emit again if still blocked later.
    if (LocationTrackingService.instance.permissionIssueNotifier.value == issue) {
      LocationTrackingService.instance.permissionIssueNotifier.value = null;
    }
  }
}

class _TrackingPermissionSheet extends StatelessWidget {
  const _TrackingPermissionSheet({required this.issue});

  final TrackingPermissionIssue issue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = switch (issue.type) {
      TrackingPermissionIssueType.deniedForever => 'Permissão bloqueada',
      TrackingPermissionIssueType.backgroundNotAllowed => 'Ative localização em segundo plano',
      TrackingPermissionIssueType.batteryOptimization => 'Desative otimização de bateria',
      TrackingPermissionIssueType.denied => 'Permissão de localização necessária',
      TrackingPermissionIssueType.unknown => 'Não foi possível ativar o rastreamento',
    };

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.location_on, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                tooltip: 'Fechar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            issue.message,
            style: tt.bodyMedium?.copyWith(height: 1.45, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _StepsCard(type: issue.type),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.visibility_off, color: cs.primary),
                  label: Text('Agora não', style: TextStyle(color: cs.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.30)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    if (!kIsWeb) {
                      await Geolocator.openAppSettings();
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.settings, color: cs.onPrimary),
                  label: Text('Abrir configurações', style: TextStyle(color: cs.onPrimary)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.type});

  final TrackingPermissionIssueType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final steps = <String>[
      '1) Abra “Permissões” do app',
      '2) Entre em “Localização”',
      '3) Selecione “Sempre” (ou “Permitir o tempo todo”)',
      '4) Volte para o app e mantenha a entrega ativa',
    ];

    final subtitle = switch (type) {
      TrackingPermissionIssueType.backgroundNotAllowed => 'Para rastrear durante a entrega, o app precisa rodar em segundo plano.',
      TrackingPermissionIssueType.deniedForever => 'A permissão foi bloqueada. Você precisa habilitar manualmente nas configurações.',
      TrackingPermissionIssueType.batteryOptimization => 'Alguns celulares pausam o GPS com a tela desligada. Desative as otimizações de bateria para este app.',
      _ => 'Siga os passos para liberar o rastreamento.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 10),
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(s, style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.35)),
            ),
        ],
      ),
    );
  }
}
