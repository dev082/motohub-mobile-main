import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:motohub/models/chat.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/nav.dart';
import 'package:motohub/theme.dart';

/// Bottom sheet with details about the current chat + linked delivery/cargo.
///
/// Opened when the user taps on the chat header.
class ChatDetailsSheet extends StatelessWidget {
  const ChatDetailsSheet({super.key, required this.entrega, required this.chat});

  final Entrega entrega;
  final Chat chat;

  String _formatDate(DateTime dt) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dt.toIso8601String();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detalhes da conversa',
                    style: context.textStyles.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(Icons.close, color: onSurfaceVariant),
                  tooltip: 'Fechar',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _Chip(label: 'Chat', value: chat.id, icon: Icons.forum_outlined),
                      _Chip(label: 'Entrega', value: entrega.id, icon: Icons.local_shipping_outlined),
                      _Chip(label: 'Carga', value: entrega.cargaId, icon: Icons.inventory_2_outlined),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(
                    label: 'Criado em',
                    value: _formatDate(chat.createdAt),
                    icon: Icons.event,
                  ),
                  _InfoRow(
                    label: 'Atualizado em',
                    value: _formatDate(chat.updatedAt),
                    icon: Icons.update,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Status',
                    value: entrega.status.displayName,
                    icon: Icons.verified_outlined,
                  ),
                  _InfoRow(
                    label: 'Rota',
                    value: (entrega.carga?.origem?.cidade != null && entrega.carga?.destino?.cidade != null)
                        ? '${entrega.carga!.origem!.cidade} → ${entrega.carga!.destino!.cidade}'
                        : '—',
                    icon: Icons.alt_route,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.pop();
                      context.push(AppRoutes.entregaDetailsPath(entrega.id));
                    },
                    icon: Icon(Icons.description_outlined, color: scheme.primary),
                    label: Text(
                      'Ver entrega',
                      style: context.textStyles.labelLarge?.copyWith(color: scheme.primary),
                    ),
                    style: ButtonStyle(
                      splashFactory: NoSplash.splashFactory,
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.pop();
                      context.push(AppRoutes.cargaDetailsPath(entrega.cargaId));
                    },
                    icon: Icon(Icons.inventory_2_outlined, color: scheme.primary),
                    label: Text(
                      'Ver carga',
                      style: context.textStyles.labelLarge?.copyWith(color: scheme.primary),
                    ),
                    style: ButtonStyle(
                      splashFactory: NoSplash.splashFactory,
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label: ',
            style: context.textStyles.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              style: context.textStyles.labelSmall?.copyWith(color: scheme.onPrimaryContainer),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(color: onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, style: context.textStyles.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
