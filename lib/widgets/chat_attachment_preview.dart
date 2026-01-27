import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Preview de anexo para mensagens do chat.
///
/// - Se for imagem: mostra thumbnail clicável e abre viewer fullscreen.
/// - Se for outro arquivo (ex.: PDF): mostra cartão com nome/tamanho e ações.
class ChatAttachmentPreview extends StatelessWidget {
  const ChatAttachmentPreview({
    super.key,
    required this.url,
    this.fileName,
    this.contentType,
    this.sizeBytes,
    this.maxImageHeight = 180,
  });

  final String url;
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;
  final double maxImageHeight;

  bool get _isImage {
    final ct = (contentType ?? '').toLowerCase();
    if (ct.startsWith('image/')) return true;
    final lower = (fileName ?? url).toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.contains('format=jpeg') ||
        lower.contains('format=png');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (_) => _ImageViewerDialog(url: url),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxImageHeight),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, _) => SizedBox(
                  height: maxImageHeight,
                  child: Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, _, __) => Container(
                  height: maxImageHeight,
                  alignment: Alignment.center,
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final name = (fileName != null && fileName!.trim().isNotEmpty) ? fileName!.trim() : 'Arquivo anexado';
    final sizeLabel = _formatBytes(sizeBytes);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outlineVariant),
            ),
            alignment: Alignment.center,
            child: Icon(_iconForFile(name, contentType), color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel,
                    style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openUrl(url),
                      icon: Icon(Icons.open_in_new, size: 18, color: scheme.primary),
                      label: Text('Abrir', style: context.textStyles.labelLarge?.copyWith(color: scheme.primary)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadUrl(url),
                      icon: Icon(Icons.download_rounded, size: 18, color: scheme.onSurfaceVariant),
                      label: Text('Baixar', style: context.textStyles.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForFile(String name, String? contentType) {
    final lower = name.toLowerCase();
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('pdf') || lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (ct.startsWith('image/') || lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.description_outlined;
  }

  static String? _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    const units = ['B', 'KB', 'MB', 'GB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final label = i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$label ${units[i]}';
  }

  static Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) debugPrint('ChatAttachmentPreview: launchUrl returned false for $url');
    } catch (e) {
      debugPrint('ChatAttachmentPreview: openUrl error: $e');
    }
  }

  static Future<void> _downloadUrl(String url) async {
    // Na prática, em Storage público, abrir em nova aba já permite baixar.
    // Mantemos separado para futuras melhorias (ex.: download direto com headers).
    return _openUrl(url);
  }
}

class _ImageViewerDialog extends StatelessWidget {
  const _ImageViewerDialog({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: scheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.9,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, _) => Center(
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
                errorWidget: (context, _, __) => Center(
                  child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant, size: 42),
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton.filledTonal(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
