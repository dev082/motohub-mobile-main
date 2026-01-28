import 'package:flutter/material.dart';
import 'package:hubfrete/models/entrega.dart';
import 'package:hubfrete/theme.dart';
import 'package:intl/intl.dart';
import 'package:hubfrete/widgets/entrega_route_preview.dart';

/// Card component for displaying entrega information
class EntregaCard extends StatelessWidget {
  final Entrega entrega;
  final VoidCallback? onTap;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onAdvanceStage;
  final bool isAdvancing;

  const EntregaCard({
    super.key,
    required this.entrega,
    this.onTap,
    this.isSelected = false,
    this.onSelect,
    this.onAdvanceStage,
    this.isAdvancing = false,
  });

  Color _getStatusColor() {
    switch (entrega.status) {
      case StatusEntrega.aguardando:
        return StatusColors.waiting;
      case StatusEntrega.saiuParaColeta:
        return StatusColors.collected;
      case StatusEntrega.saiuParaEntrega:
        return StatusColors.inTransit;
      case StatusEntrega.entregue:
        return StatusColors.delivered;
      case StatusEntrega.problema:
        return StatusColors.problem;
      case StatusEntrega.cancelada:
        return StatusColors.cancelled;
    }
  }

  bool get _isActiveEntrega {
    return [
      StatusEntrega.aguardando,
      StatusEntrega.saiuParaColeta,
      StatusEntrega.saiuParaEntrega,
    ].contains(entrega.status);
  }

  ({String label, IconData icon})? _nextStageAction() {
    // Baseado na enum do Supabase: status_entrega
    // aguardando -> saiu_para_coleta -> saiu_para_entrega -> entregue
    switch (entrega.status) {
      case StatusEntrega.aguardando:
        return (label: 'Sair p/ coleta', icon: Icons.play_arrow);
      case StatusEntrega.saiuParaColeta:
        return (label: 'Sair p/ entrega', icon: Icons.route);
      case StatusEntrega.saiuParaEntrega:
        return (label: 'Entreguei', icon: Icons.check_circle);
      case StatusEntrega.entregue:
      case StatusEntrega.problema:
      case StatusEntrega.cancelada:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = _nextStageAction();
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isActiveEntrega) ...[
                EntregaCardActionRow(
                  isSelected: isSelected,
                  onSelect: onSelect,
                  primaryActionLabel: action?.label,
                  primaryActionIcon: action?.icon,
                  onPrimaryAction: isSelected ? onAdvanceStage : null,
                  isPrimaryLoading: isAdvancing,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_isActiveEntrega) ...[
                EntregaRoutePreview(
                  origem: entrega.carga?.origem,
                  destino: entrega.carga?.destino,
                  consumoKmPorLitro: 25, // estimativa padrão (pode virar config no futuro)
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Header with code and status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      entrega.codigo ?? entrega.carga?.codigo ?? 'SEM CÓDIGO',
                      style: context.textStyles.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      entrega.status.displayName,
                      style: context.textStyles.labelSmall?.copyWith(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Carga description
              if (entrega.carga != null) ...[
                Text(
                  entrega.carga!.descricao,
                  style: context.textStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Route info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Origem',
                              style: context.textStyles.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          entrega.carga?.origem != null
                              ? '${entrega.carga!.origem!.cidade} - ${entrega.carga!.origem!.estado}'
                              : 'Não informado',
                          style: context.textStyles.bodySmall?.semiBold,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Destino',
                              style: context.textStyles.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          entrega.carga?.destino != null
                              ? '${entrega.carga!.destino!.cidade} - ${entrega.carga!.destino!.estado}'
                              : 'Não informado',
                          style: context.textStyles.bodySmall?.semiBold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Additional info
              Row(
                children: [
                  if (entrega.pesoAlocadoKg != null) ...[
                    Icon(
                      Icons.scale,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${entrega.pesoAlocadoKg!.toStringAsFixed(0)} kg',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (entrega.valorFrete != null)
                    Text(
                      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                          .format(entrega.valorFrete),
                      style: context.textStyles.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EntregaCardActionRow extends StatelessWidget {
  const EntregaCardActionRow({
    super.key,
    required this.isSelected,
    this.onSelect,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.isPrimaryLoading = false,
  });

  final bool isSelected;
  final VoidCallback? onSelect;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final bool isPrimaryLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _SelectEntregaButton(
            isSelected: isSelected,
            onPressed: onSelect,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: _AdvanceStageButton(
            label: primaryActionLabel,
            icon: primaryActionIcon,
            onPressed: onPrimaryAction,
            isLoading: isPrimaryLoading,
            activeBg: cs.primary,
            activeFg: cs.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _SelectEntregaButton extends StatelessWidget {
  const _SelectEntregaButton({required this.isSelected, this.onPressed});

  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isSelected ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final icon = isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked;
    final label = isSelected ? 'Ativa' : 'Selecionar';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isSelected ? cs.primary.withValues(alpha: 0.35) : cs.outline.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: isSelected ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isSelected ? cs.primary : fg),
                const SizedBox(width: AppSpacing.xs),
                Text(label, style: context.textStyles.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvanceStageButton extends StatelessWidget {
  const _AdvanceStageButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isLoading,
    required this.activeBg,
    required this.activeFg,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color activeBg;
  final Color activeFg;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && label != null && icon != null;
    if (label == null || icon == null) {
      return _DisabledStagePill();
    }

    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: activeBg,
          foregroundColor: activeFg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          textStyle: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: activeFg),
              )
            : Icon(icon, size: 18, color: activeFg),
        label: Text(isLoading ? 'Atualizando…' : label!, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _DisabledStagePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
          const SizedBox(width: AppSpacing.xs),
          Text('Finalizada', style: context.textStyles.labelLarge?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.75), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
