import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hubfrete/theme.dart';

class PickedBinaryFile {
  final String name;
  final Uint8List bytes;
  final String? contentType;

  const PickedBinaryFile({required this.name, required this.bytes, this.contentType});
}

/// Picker and preview for multiple photos.
///
/// Uses [image_picker] and works on mobile and web.
class PhotoGridPicker extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<XFile> files;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveAt;
  final bool required;

  const PhotoGridPicker({
    super.key,
    required this.title,
    this.subtitle,
    required this.files,
    required this.onAdd,
    required this.onRemoveAt,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      required ? '$title *' : title,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (files.isEmpty)
            _EmptyAttachmentsHint(
              icon: Icons.photo_library_outlined,
              text: required
                  ? 'Adicione as fotos obrigatórias (ângulos externos do veículo inteiro).'
                  : 'Adicione fotos para melhorar o seu perfil.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 560 ? 4 : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: files.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                  ),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: FutureBuilder<Uint8List>(
                              future: file.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                }
                                return Image.memory(snapshot.data!, fit: BoxFit.cover);
                              },
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => onRemoveAt(index),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A single document picker tile that supports images and PDFs.
class DocumentPickerTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PickedBinaryFile? file;
  final bool required;
  final VoidCallback onPick;
  /// Optional secondary action, e.g. "Tirar foto".
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryPick;
  final VoidCallback? onClear;

  const DocumentPickerTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.file,
    this.required = false,
    required this.onPick,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryPick,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              _iconForFile(file?.name),
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(required ? '$title *' : title, style: theme.textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (file == null)
                  Text(
                    required ? 'Nenhum arquivo anexado (obrigatório).' : 'Nenhum arquivo anexado.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            file!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (onClear != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: onClear,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (onSecondaryPick != null && secondaryLabel != null) ...[
                OutlinedButton.icon(
                  onPressed: onSecondaryPick,
                  icon: Icon(secondaryIcon ?? Icons.photo_camera_outlined, size: 18),
                  label: Text(secondaryLabel!),
                ),
              ],
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(file == null ? 'Anexar' : 'Trocar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconForFile(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.description_outlined;
  }
}

class _EmptyAttachmentsHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyAttachmentsHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper method for picking a single document using file_picker.
///
/// Supports images and PDFs.
Future<PickedBinaryFile?> pickDocumentFile() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
  );
  final file = result?.files.single;
  if (file == null) return null;
  final bytes = file.bytes;
  if (bytes == null) return null;
  return PickedBinaryFile(
    name: file.name,
    bytes: bytes,
    contentType: _guessContentType(file.name),
  );
}

/// Helper method for taking a photo using the device camera.
///
/// On web, this will fallback to the browser camera/file prompt.
Future<PickedBinaryFile?> pickCameraPhotoFile() async {
  final picker = ImagePicker();
  final xfile = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 82,
    maxWidth: 2048,
  );
  if (xfile == null) return null;
  final bytes = await xfile.readAsBytes();
  final name = (xfile.name.trim().isEmpty) ? 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg' : xfile.name;
  return PickedBinaryFile(
    name: name,
    bytes: bytes,
    contentType: _guessContentType(name) ?? 'image/jpeg',
  );
}

String? _guessContentType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}
