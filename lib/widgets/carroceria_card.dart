import 'package:flutter/material.dart';
import 'package:hubfrete/models/carroceria.dart';
import 'package:hubfrete/theme.dart';

/// Card widget to display trailer preview
class CarroceriaCard extends StatelessWidget {
  final Carroceria carroceria;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const CarroceriaCard({
    super.key,
    required this.carroceria,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (carroceria.fotoUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                child: Image.network(
                  carroceria.fotoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                ),
              )
            else
              _buildPlaceholderImage(),
            Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          carroceria.placa,
                          style: context.textStyles.titleLarge?.bold,
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    carroceria.tipo,
                    style: context.textStyles.bodyMedium?.withColor(Colors.grey),
                  ),
                  if (carroceria.marca != null || carroceria.modelo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${carroceria.marca ?? ''} ${carroceria.modelo ?? ''}'.trim(),
                      style: context.textStyles.bodyMedium,
                    ),
                  ],
                  if (carroceria.ano != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ano: ${carroceria.ano}',
                      style: context.textStyles.bodySmall?.withColor(Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (carroceria.capacidadeKg != null)
                        _buildChip(
                          icon: Icons.scale,
                          label: '${carroceria.capacidadeKg!.toStringAsFixed(0)} kg',
                        ),
                      if (carroceria.capacidadeM3 != null)
                        _buildChip(
                          icon: Icons.inventory_2,
                          label: '${carroceria.capacidadeM3!.toStringAsFixed(1)} m³',
                        ),
                      if (!carroceria.ativo)
                        _buildChip(
                          icon: Icons.cancel,
                          label: 'Inativo',
                          color: Colors.grey,
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

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFE0E0E0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      child: const Icon(
        Icons.view_carousel,
        size: 64,
        color: Colors.white,
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label, Color? color}) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color ?? Colors.grey),
      label: Text(label),
      labelStyle: TextStyle(fontSize: 12, color: color ?? Colors.grey),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
