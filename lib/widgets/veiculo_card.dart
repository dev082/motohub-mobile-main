import 'package:flutter/material.dart';
import 'package:motohub/models/veiculo.dart';
import 'package:motohub/theme.dart';

/// Card widget to display vehicle preview
class VeiculoCard extends StatelessWidget {
  final Veiculo veiculo;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const VeiculoCard({
    super.key,
    required this.veiculo,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (veiculo.fotoUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                child: Image.network(
                  veiculo.fotoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(context),
                ),
              )
            else
              _buildPlaceholderImage(context),
            Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          veiculo.placa,
                          style: context.textStyles.titleLarge?.bold,
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          color: cs.error,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${veiculo.tipo.label} • ${veiculo.carroceria.label}',
                    style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                  ),
                  if (veiculo.marca != null || veiculo.modelo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${veiculo.marca ?? ''} ${veiculo.modelo ?? ''}'.trim(),
                      style: context.textStyles.bodyMedium,
                    ),
                  ],
                  if (veiculo.ano != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ano: ${veiculo.ano}',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (veiculo.capacidadeKg != null)
                        _buildChip(
                          icon: Icons.scale,
                          label: '${veiculo.capacidadeKg!.toStringAsFixed(0)} kg',
                        ),
                      if (veiculo.capacidadeM3 != null)
                        _buildChip(
                          icon: Icons.inventory_2,
                          label: '${veiculo.capacidadeM3!.toStringAsFixed(1)} m³',
                        ),
                      if (veiculo.rastreador)
                        _buildChip(
                          icon: Icons.gps_fixed,
                          label: 'Rastreador',
                          color: cs.primary,
                        ),
                      if (veiculo.seguroAtivo)
                        _buildChip(
                          icon: Icons.verified_user,
                          label: 'Seguro',
                          color: cs.tertiary,
                        ),
                      if (!veiculo.ativo)
                        _buildChip(
                          icon: Icons.cancel,
                          label: 'Inativo',
                          color: cs.onSurfaceVariant,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      child: Icon(Icons.local_shipping, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
    );
  }

  Widget _buildChip({required IconData icon, required String label, Color? color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: TextStyle(color: color),
      backgroundColor: color?.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }
}
