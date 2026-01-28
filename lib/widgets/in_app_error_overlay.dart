import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/app_user_alert.dart';
import 'package:hubfrete/nav.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/notification_service.dart';
import 'package:provider/provider.dart';

/// Global in-app “push notification” overlay.
///
/// It listens to [AppProvider.activeUserAlert] and shows a modern top banner.
/// The banner has a primary action to help the user resolve the problem.
class InAppErrorOverlay extends StatelessWidget {
  final Widget child;
  const InAppErrorOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUserAlert?>(
      valueListenable: NotificationService.instance.activeInAppAlertListenable,
      builder: (context, alert, _) {
        if (alert == null) return child;
        return Stack(
          children: [
            child,
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.paddingOf(context).top + 10,
              child: _AlertBanner(alert: alert),
            ),
          ],
        );
      },
    );
  }
}

class _AlertBanner extends StatefulWidget {
  final AppUserAlert alert;
  const _AlertBanner({required this.alert});

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alert = widget.alert;
    final color = alert.severityColor(scheme);

    return AnimatedSlide(
      offset: Offset(0, _expanded ? 0 : 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(alert.severityIcon(), color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                      maxLines: _expanded ? 6 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_expanded) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionButton(
                            label: alert.actionLabel,
                            color: color,
                            onPressed: () => _handlePrimary(context, alert),
                          ),
                          _ActionButton(
                            label: 'Fechar',
                            color: scheme.outline,
                            outlined: true,
                            onPressed: () => NotificationService.instance.dismissInAppAlert(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dispensar',
              onPressed: () => NotificationService.instance.dismissInAppAlert(),
              icon: Icon(Icons.close, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrimary(BuildContext context, AppUserAlert alert) async {
    switch (alert.action) {
      case AppUserAlertAction.relogin:
        final app = context.read<AppProvider>();
        await app.signOut();
        if (!context.mounted) return;
        context.go(AppRoutes.login);
        NotificationService.instance.dismissInAppAlert();
        return;
      case AppUserAlertAction.showFixSteps:
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _FixStepsSheet(alert: alert),
        );
        return;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.color, required this.onPressed, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _FixStepsSheet extends StatelessWidget {
  final AppUserAlert alert;
  const _FixStepsSheet({required this.alert});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = alert.severityColor(scheme);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(alert.severityIcon(), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(alert.message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Como resolver', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...alert.steps.indexed.map((e) {
                    final idx = e.$1 + 1;
                    final step = e.$2;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$idx',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(step, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: alert.technicalDetails == null
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: _supportPayload(alert)));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detalhes copiados.')));
                          },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar detalhes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Ok'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _supportPayload(AppUserAlert alert) {
    final buf = StringBuffer();
    buf.writeln('Erro: ${alert.code}');
    buf.writeln('Quando: ${alert.createdAt.toIso8601String()}');
    if (alert.technicalDetails != null) {
      buf.writeln('Detalhes: ${alert.technicalDetails}');
    }
    return buf.toString();
  }
}
