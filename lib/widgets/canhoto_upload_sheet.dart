import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/attachment_pickers.dart';

/// Bottom sheet to require the driver to attach the delivery receipt (canhoto)
/// before marking the delivery as completed.
///
/// Use with:
/// ```dart
/// final ok = await showModalBottomSheet<bool>(...);
/// ```
class CanhotoUploadSheet extends StatefulWidget {
  final Future<void> Function(PickedBinaryFile file) onSubmit;

  const CanhotoUploadSheet({super.key, required this.onSubmit});

  @override
  State<CanhotoUploadSheet> createState() => _CanhotoUploadSheetState();
}

class _CanhotoUploadSheetState extends State<CanhotoUploadSheet> {
  PickedBinaryFile? _file;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _pick() async {
    try {
      final picked = await pickDocumentFile();
      if (!mounted) return;
      if (picked == null) return;
      setState(() {
        _file = picked;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível selecionar o arquivo.');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await pickCameraPhotoFile();
      if (!mounted) return;
      if (picked == null) return;
      setState(() {
        _file = picked;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível abrir a câmera.');
    }
  }

  Future<void> _submit() async {
    if (_file == null) {
      setState(() => _error = 'Anexe o canhoto para finalizar.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_file!);
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Falha ao enviar o canhoto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Anexar canhoto', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Para finalizar a entrega, anexe o canhoto (foto ou PDF).',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => context.pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AbsorbPointer(
              absorbing: _isSubmitting,
              child: DocumentPickerTile(
                title: 'Canhoto da entrega',
                subtitle: 'Obrigatório: foto do canhoto assinado ou PDF.',
                required: true,
                file: _file,
                onPick: _pick,
                secondaryLabel: 'Tirar foto',
                secondaryIcon: Icons.photo_camera_outlined,
                onSecondaryPick: _takePhoto,
                onClear: () => setState(() => _file = null),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => context.pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(_isSubmitting ? 'Enviando…' : 'Anexar e finalizar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
