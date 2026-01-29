import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Tela de bloqueio para solicitar permissões críticas de rastreamento
class TrackingPermissionBlocker extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const TrackingPermissionBlocker({super.key, required this.onPermissionsGranted});

  @override
  State<TrackingPermissionBlocker> createState() => _TrackingPermissionBlockerState();
}

class _TrackingPermissionBlockerState extends State<TrackingPermissionBlocker> {
  bool _isChecking = true;
  bool _locationGranted = false;
  bool _locationAlwaysGranted = false;
  bool _notificationGranted = false;
  bool _batteryOptimizationDisabled = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isChecking = true);

    try {
      // Localização
      final locPerm = await Geolocator.checkPermission();
      _locationGranted = locPerm == LocationPermission.always || locPerm == LocationPermission.whileInUse;
      _locationAlwaysGranted = locPerm == LocationPermission.always;

      // Notificações
      _notificationGranted = await ph.Permission.notification.isGranted;

      // Otimização de bateria
      _batteryOptimizationDisabled = await ph.Permission.ignoreBatteryOptimizations.isGranted;

      // Se todas as permissões críticas estiverem ok, libera o app
      if (_locationAlwaysGranted && _notificationGranted && _batteryOptimizationDisabled) {
        widget.onPermissionsGranted();
      }
    } catch (e) {
      debugPrint('Erro ao verificar permissões: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _requestLocationPermission() async {
    final result = await Geolocator.requestPermission();
    await _checkAllPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    await ph.Permission.notification.request();
    await _checkAllPermissions();
  }

  Future<void> _requestBatteryOptimization() async {
    await ph.Permission.ignoreBatteryOptimizations.request();
    await _checkAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isChecking) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(Icons.location_on, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Permissões Necessárias',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'O HubFrete Motoristas precisa das seguintes permissões para funcionar corretamente:',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    _PermissionTile(
                      icon: Icons.location_on,
                      title: 'Localização em Segundo Plano',
                      subtitle: 'Necessário para rastrear sua rota mesmo com o app fechado',
                      granted: _locationAlwaysGranted,
                      onTap: _requestLocationPermission,
                    ),
                    _PermissionTile(
                      icon: Icons.notifications,
                      title: 'Notificações',
                      subtitle: 'Receba alertas sobre entregas e atualizações',
                      granted: _notificationGranted,
                      onTap: _requestNotificationPermission,
                    ),
                    _PermissionTile(
                      icon: Icons.battery_charging_full,
                      title: 'Ignorar Otimização de Bateria',
                      subtitle: 'Evita que o Android encerre o rastreamento em segundo plano',
                      granted: _batteryOptimizationDisabled,
                      onTap: _requestBatteryOptimization,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checkAllPermissions,
                icon: const Icon(Icons.refresh),
                label: const Text('Verificar Novamente'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: granted ? Colors.green : theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: granted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(
                onPressed: onTap,
                child: const Text('Permitir'),
              ),
      ),
    );
  }
}
