import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet that shows full details for an [Entrega].
///
/// Designed for the Histórico list, where users expect to review all delivery
/// information without depending on an extra details route.
class EntregaDetailsSheet extends StatelessWidget {
  final Entrega entrega;

  const EntregaDetailsSheet({super.key, required this.entrega});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dt.toIso8601String();
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

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
                    'Detalhes da entrega',
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _Chip(
                        label: entrega.codigo ?? entrega.carga?.codigo ?? 'SEM CÓDIGO',
                        icon: Icons.confirmation_number,
                      ),
                      _Chip(label: entrega.status.displayName, icon: Icons.local_shipping),
                    ],
                  ),
                  if (entrega.carga?.descricao != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      entrega.carga!.descricao,
                      style: context.textStyles.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _SectionTitle(title: 'Rota'),
                  _InfoRow(
                    label: 'Origem',
                    value: entrega.carga?.origem != null
                        ? '${entrega.carga!.origem!.cidade} - ${entrega.carga!.origem!.estado}'
                        : 'Não informado',
                    icon: Icons.circle,
                  ),
                  _InfoRow(
                    label: 'Destino',
                    value: entrega.carga?.destino != null
                        ? '${entrega.carga!.destino!.cidade} - ${entrega.carga!.destino!.estado}'
                        : 'Não informado',
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle(title: 'Datas'),
                  _InfoRow(label: 'Coletado em', value: _formatDate(entrega.coletadoEm), icon: Icons.event_available),
                  _InfoRow(label: 'Entregue em', value: _formatDate(entrega.entregueEm), icon: Icons.task_alt),
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle(title: 'Financeiro & Carga'),
                  _InfoRow(
                    label: 'Peso alocado',
                    value: entrega.pesoAlocadoKg != null ? '${entrega.pesoAlocadoKg!.toStringAsFixed(0)} kg' : '—',
                    icon: Icons.scale,
                  ),
                  _InfoRow(
                    label: 'Valor do frete',
                    value: entrega.valorFrete != null ? money.format(entrega.valorFrete) : '—',
                    icon: Icons.payments,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle(title: 'Recebedor'),
                  _InfoRow(label: 'Nome', value: entrega.nomeRecebedor ?? '—', icon: Icons.person),
                  _InfoRow(label: 'Documento', value: entrega.documentoRecebedor ?? '—', icon: Icons.badge),
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle(title: 'Anexos & Observações'),
                  CteDocumentRow(cteUrl: entrega.cteUrl),
                  _InfoRow(
                    label: 'Observações',
                    value: (entrega.observacoes?.trim().isNotEmpty ?? false) ? entrega.observacoes!.trim() : '—',
                    icon: Icons.notes,
                    multiline: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle(title: 'IDs'),
                  _InfoRow(label: 'Entrega ID', value: entrega.id, icon: Icons.fingerprint),
                  _InfoRow(label: 'Carga ID', value: entrega.cargaId, icon: Icons.inventory_2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: context.textStyles.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Row for the CT-e document.
///
/// Shows a friendly action button instead of printing a long URL.
/// Generates a signed URL with temporary permission to bypass RLS.
class CteDocumentRow extends StatefulWidget {
  final String? cteUrl;

  const CteDocumentRow({super.key, required this.cteUrl});

  @override
  State<CteDocumentRow> createState() => _CteDocumentRowState();
}

class _CteDocumentRowState extends State<CteDocumentRow> {
  final _entregaService = EntregaService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final url = widget.cteUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.description, size: 18, color: onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 110,
            child: Text(
              'CT-e',
              style: context.textStyles.labelMedium?.copyWith(color: onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: hasUrl
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : () => _openCte(context, url),
                      style: ButtonStyle(
                        splashFactory: NoSplash.splashFactory,
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        ),
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                            )
                          : Icon(Icons.open_in_new, size: 18, color: Theme.of(context).colorScheme.onSecondaryContainer),
                      label: Text(
                        _isLoading ? 'Gerando link...' : 'Ver documento',
                        style: context.textStyles.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer),
                      ),
                    ),
                  )
                : Text('—', style: context.textStyles.bodyMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _openCte(BuildContext context, String url) async {
    setState(() => _isLoading = true);

    try {
      // Generate signed URL with temporary permission
      final signedUrl = await _entregaService.getCteSignedUrl(url);

      if (!mounted) return;

      if (signedUrl == null || signedUrl.isEmpty) {
        debugPrint('Falha ao gerar URL assinada para: $url');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o link de acesso.')),
        );
        return;
      }

      final uri = Uri.tryParse(signedUrl);
      if (uri == null || !uri.hasScheme) {
        debugPrint('URL assinada inválida: $signedUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link do CT-e inválido.')),
          );
        }
        return;
      }

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        debugPrint('Falha ao abrir CT-e: $signedUrl');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o documento.')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao abrir CT-e: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao abrir o documento.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool multiline;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
            child: Text(
              value,
              style: context.textStyles.bodyMedium?.copyWith(height: multiline ? 1.45 : null),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: context.textStyles.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
