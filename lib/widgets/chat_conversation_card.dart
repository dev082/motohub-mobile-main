import 'package:flutter/material.dart';
import 'package:motohub/models/chat.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:motohub/theme.dart';

/// Card reutilizável para itens de conversa (lista e histórico).
///
/// Mostra:
/// - título (código da entrega/carga)
/// - status da entrega (ex.: Entregue / Cancelada)
/// - preview da última mensagem com autor
/// - rota origem → destino (quando disponível)
class ChatConversationCard extends StatelessWidget {
  const ChatConversationCard({
    super.key,
    required this.entrega,
    required this.lastMessageFuture,
    required this.onTap,
    this.leadingIcon = Icons.chat_bubble,
  });

  final Entrega entrega;
  final Future<Mensagem?> lastMessageFuture;
  final VoidCallback onTap;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = entrega.codigo ?? entrega.carga?.codigo ?? 'Entrega';
    final route = entrega.carga != null
        ? '${entrega.carga!.origem?.cidade} → ${entrega.carga!.destino?.cidade}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(leadingIcon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: context.textStyles.titleMedium?.semiBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusPill(status: entrega.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<Mensagem?>(
                      future: lastMessageFuture,
                      builder: (context, snapshot) {
                        final msg = snapshot.data;
                        final text = _buildPreviewText(msg);
                        return Text(
                          text,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    if (route != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        route,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreviewText(Mensagem? m) {
    if (m == null) {
      // Fallback: status em vez de deixar vazio.
      return entrega.status.displayName;
    }
    final authUid = SupabaseConfig.client.auth.currentUser?.id;
    final isMe = authUid != null && m.senderId == authUid;
    final who = isMe
        ? 'Você'
        : (m.senderNome.trim().isNotEmpty ? m.senderNome.trim() : m.senderTipo.displayName);
    return '$who: ${m.conteudo}'.trim();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final StatusEntrega status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final ({Color bg, Color fg, IconData icon}) style = switch (status) {
      StatusEntrega.entregue => (bg: scheme.tertiaryContainer, fg: scheme.onTertiaryContainer, icon: Icons.check_circle_outline),
      StatusEntrega.cancelada => (bg: scheme.errorContainer, fg: scheme.onErrorContainer, icon: Icons.cancel_outlined),
      StatusEntrega.problema => (bg: scheme.errorContainer, fg: scheme.onErrorContainer, icon: Icons.report_gmailerrorred_outlined),
      _ => (bg: scheme.secondaryContainer, fg: scheme.onSecondaryContainer, icon: Icons.timelapse),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.fg),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: context.textStyles.labelSmall?.copyWith(color: style.fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
