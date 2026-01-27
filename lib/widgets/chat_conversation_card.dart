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
    this.leadingIcon,
    this.accentColor,
  });

  final Entrega entrega;
  final Future<Mensagem?> lastMessageFuture;
  final VoidCallback onTap;

  /// Leading icon shown in the colored tile.
  /// If null, defaults to `Icons.chat_bubble_outline`.
  final IconData? leadingIcon;

  /// Accent color used for the left border and status chip.
  /// If null, defaults to theme primary.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = entrega.codigo ?? entrega.carga?.codigo ?? 'Entrega';
    final route = entrega.carga != null
        ? '${entrega.carga!.origem?.cidade} → ${entrega.carga!.destino?.cidade}'
        : null;

    final accent = accentColor ?? scheme.primary;
    final icon = leadingIcon ?? Icons.chat_bubble_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(width: 4, height: 92, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(icon, color: accent, size: 22),
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
                                _StatusChip(status: entrega.status, accent: accent),
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
                              const SizedBox(height: 8),
                              Text(
                                route.toUpperCase(),
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                  letterSpacing: 0.6,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.chevron_right, color: scheme.outline.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
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

    final legacyFile = m.legacyAttachmentFileName;
    final hasAttachment = (m.anexoUrl != null && m.anexoUrl!.trim().isNotEmpty) || legacyFile != null;
    final hasText = m.conteudo.trim().isNotEmpty && !(m.isLegacyAttachmentOnly && legacyFile != null);
    if (hasAttachment && !hasText) {
      final name = (m.anexoNome != null && m.anexoNome!.trim().isNotEmpty) ? m.anexoNome!.trim() : (legacyFile ?? 'Anexo');
      final isImage = (m.anexoTipo ?? '').toLowerCase().startsWith('image/') ||
          name.toLowerCase().endsWith('.png') ||
          name.toLowerCase().endsWith('.jpg') ||
          name.toLowerCase().endsWith('.jpeg') ||
          name.toLowerCase().endsWith('.webp');
      return '$who: ${isImage ? '🖼️ Foto' : '📎 $name'}'.trim();
    }
    if (hasAttachment && hasText) {
      return '$who: 📎 ${m.conteudo}'.trim();
    }
    return '$who: ${m.conteudo}'.trim();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.accent});
  final StatusEntrega status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = status.displayName.toUpperCase();
    final Color fg = switch (status) {
      StatusEntrega.problema || StatusEntrega.cancelada => scheme.error,
      _ => accent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
