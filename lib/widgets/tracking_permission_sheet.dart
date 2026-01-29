import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hubfrete/services/location_tracking_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Modal (hard lock) usado para bloquear ações de operação quando as permissões
/// mínimas de rastreamento não estão atendidas.
///
/// Regra prática:
/// - Localização: While in use OU Always
/// - Android: Notificações habilitadas (para o Foreground Service)
/// - Always é recomendado, mas não obrigatório.
class TrackingPermissionSheet extends StatefulWidget {
  const TrackingPermissionSheet({super.key, this.reason});

  final String? reason;

  static Future<bool> ensureTrackingReady(BuildContext context, {String? reason}) async {
    final readiness = await LocationTrackingService.instance.getTrackingReadiness();
    if (readiness.canStartTracking) return true;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => TrackingPermissionSheet(reason: reason),
    );
    return result == true;
  }

  @override
  State<TrackingPermissionSheet> createState() => _TrackingPermissionSheetState();
}

class _TrackingPermissionSheetState extends State<TrackingPermissionSheet> {
  bool _isLoading = true;
  TrackingReadiness? _readiness;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      _readiness = await LocationTrackingService.instance.getTrackingReadiness();
    } catch (e) {
      debugPrint('[TrackingPermissionSheet] Failed to refresh: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestLocation() async {
    try {
      await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('[TrackingPermissionSheet] requestLocation error: $e');
    }
    await _refresh();
  }

  Future<void> _requestNotifications() async {
    try {
      await ph.Permission.notification.request();
    } catch (e) {
      debugPrint('[TrackingPermissionSheet] requestNotifications error: $e');
    }
    await _refresh();
  }

  Future<void> _openSettings() async {
    try {
      await ph.openAppSettings();
    } catch (e) {
      debugPrint('[TrackingPermissionSheet] openAppSettings error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readiness = _readiness;

    final canProceed = readiness?.canStartTracking == true;
    final hasAnyLocation = readiness?.hasAnyLocation == true;
    final hasAlways = readiness?.hasAlwaysLocation == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.location_off_outlined, color: theme.colorScheme.onErrorContainer),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ative o rastreamento para iniciar a operação',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if ((widget.reason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.reason!.trim(),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _RequirementTile(
              icon: Icons.my_location,
              title: 'Localização',
              subtitle: hasAnyLocation
                  ? (hasAlways
                      ? 'Permitir o tempo todo (ideal)'
                      : 'Permitir durante o uso (mínimo)')
                  : 'Necessário para rastrear a carga durante a viagem',
              status: hasAnyLocation ? _ReqStatus.ok : _ReqStatus.blocked,
              actionLabel: hasAnyLocation ? 'Rever' : 'Permitir',
              onAction: _requestLocation,
            ),
            const SizedBox(height: AppSpacing.sm),

            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
              _RequirementTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notificação fixa (Android)',
                subtitle: (readiness?.notificationGranted == true)
                    ? 'Mantém o rastreamento ativo mesmo com Waze/Maps aberto'
                    : 'Necessário para o Foreground Service no Android',
                status: (readiness?.notificationGranted == true) ? _ReqStatus.ok : _ReqStatus.blocked,
                actionLabel: (readiness?.notificationGranted == true) ? 'Ok' : 'Permitir',
                onAction: (readiness?.notificationGranted == true) ? null : _requestNotifications,
              ),
              const SizedBox(height: AppSpacing.sm),
              _RequirementTile(
                icon: Icons.battery_saver_outlined,
                title: 'Otimização de bateria (recomendado)',
                subtitle: (readiness?.ignoreBatteryOptimizationsGranted == true)
                    ? 'Bom — ajuda a evitar pausas no rastreamento'
                    : 'Recomendado para viagens longas (Android)',
                status: (readiness?.ignoreBatteryOptimizationsGranted == true) ? _ReqStatus.ok : _ReqStatus.warn,
                actionLabel: (readiness?.ignoreBatteryOptimizationsGranted == true) ? 'Ok' : 'Ajustar',
                onAction: (readiness?.ignoreBatteryOptimizationsGranted == true)
                    ? null
                    : () async {
                        try {
                          await ph.Permission.ignoreBatteryOptimizations.request();
                        } catch (e) {
                          debugPrint('[TrackingPermissionSheet] request ignoreBatteryOptimizations error: $e');
                        }
                        await _refresh();
                      },
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _openSettings,
                  child: const Text('Configurações'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: canProceed ? () => context.pop(true) : _refresh,
                  child: Text(canProceed ? 'Continuar' : 'Verificar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Dica: “Permitir o tempo todo” é o ideal para rastrear enquanto você usa o Waze/Maps.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

enum _ReqStatus { ok, warn, blocked }

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _ReqStatus status;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (bg, fg, badgeText) = switch (status) {
      _ReqStatus.ok => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
          'OK'
        ),
      _ReqStatus.warn => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
          'Recomendado'
        ),
      _ReqStatus.blocked => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
          'Obrigatório'
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: fg),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
                      child: Text(badgeText, style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
