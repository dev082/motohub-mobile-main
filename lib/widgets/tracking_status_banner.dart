import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hubfrete/services/location_tracking_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/tracking_permission_sheet.dart';

/// Banner de “soft lock”: não bloqueia o app, mas deixa claro que rastreamento
/// está desativado e orienta o motorista a habilitar.
class TrackingStatusBanner extends StatelessWidget {
  const TrackingStatusBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrackingReadiness>(
      future: LocationTrackingService.instance.getTrackingReadiness(),
      builder: (context, snap) {
        final readiness = snap.data;
        if (readiness == null) return const SizedBox.shrink();
        if (readiness.canStartTracking) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final title = '⚠️ Rastreamento desativado';
        final subtitle = !readiness.hasAnyLocation
            ? 'Habilite a localização para iniciar viagens e enviar sua rota.'
            : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && !readiness.notificationGranted)
                ? 'No Android, ative as notificações para manter o rastreamento em segundo plano.'
                : 'Habilite as permissões para continuar.';

        return Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => TrackingPermissionSheet.ensureTrackingReady(
                    context,
                    reason: 'Para iniciar a operação, precisamos do rastreamento ativo.',
                  ),
                  style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.onErrorContainer),
                  child: Text('Ativar', style: TextStyle(color: theme.colorScheme.errorContainer)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
