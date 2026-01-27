import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/theme.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

/// Bottom sheet to personalize the chat wallpaper.
///
/// - Uploads an image to Supabase Storage via [AppProvider].
/// - Persists URL + opacity locally (secure storage).
class ChatWallpaperSheet extends StatefulWidget {
  const ChatWallpaperSheet({super.key});

  @override
  State<ChatWallpaperSheet> createState() => _ChatWallpaperSheetState();
}

class _ChatWallpaperSheetState extends State<ChatWallpaperSheet> {
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final contentType = _inferContentType(file.name, fallback: file.mimeType);
      await _upload(bytes: bytes, contentType: contentType);
    } catch (e) {
      debugPrint('Pick wallpaper (gallery) error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao selecionar imagem: $e')));
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null) return;
      final contentType = _inferContentType(file.name);
      await _upload(bytes: bytes, contentType: contentType);
    } catch (e) {
      debugPrint('Pick wallpaper (file) error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao selecionar arquivo: $e')));
    }
  }

  Future<void> _upload({required Uint8List bytes, required String contentType}) async {
    setState(() => _isUploading = true);
    try {
      final provider = context.read<AppProvider>();
      final url = await provider.uploadAndSetChatWallpaper(bytes: bytes, contentType: contentType);
      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Não foi possível salvar o wallpaper.')));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Wallpaper atualizado.')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = context.watch<AppProvider>();
    final url = provider.chatWallpaperUrl;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Personalizar wallpaper', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: _isUploading ? null : () => context.pop(),
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'O wallpaper é salvo localmente no seu dispositivo e aparece em todas as conversas.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),

            _WallpaperPreview(url: url, isUploading: _isUploading),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isUploading ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galeria'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFile,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Arquivo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            Text('Opacidade', style: theme.textTheme.titleSmall),
            Slider(
              value: provider.chatWallpaperOpacity,
              min: 0.0,
              max: 0.5,
              divisions: 10,
              label: '${(provider.chatWallpaperOpacity * 100).round()}%',
              onChanged: _isUploading ? null : (v) => provider.setChatWallpaperOpacity(v),
            ),

            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    url == null ? 'Sem wallpaper (fundo sólido).' : 'Wallpaper ativo.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (url != null)
                  TextButton.icon(
                    onPressed: _isUploading ? null : () => provider.setChatWallpaperUrl(null),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remover'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WallpaperPreview extends StatelessWidget {
  const _WallpaperPreview({required this.url, required this.isUploading});

  final String? url;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 148,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: url == null
                ? Center(
                    child: Text(
                      'Pré-visualização',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                : _buildWallpaperImage(url!, scheme),
          ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                color: scheme.surface.withValues(alpha: 0.65),
                alignment: Alignment.center,
                child: CircularProgressIndicator(color: scheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWallpaperImage(String dataUri, ColorScheme scheme) {
    try {
      if (dataUri.startsWith('data:')) {
        // Parse data URI
        final commaIndex = dataUri.indexOf(',');
        if (commaIndex == -1) return _errorWidget(scheme);
        
        final base64Data = dataUri.substring(commaIndex + 1);
        final bytes = base64Decode(base64Data);
        
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => _errorWidget(scheme),
        );
      } else {
        // Fallback for old network URLs
        return Image.network(
          dataUri,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => _errorWidget(scheme),
        );
      }
    } catch (e) {
      debugPrint('Wallpaper preview decode error: $e');
      return _errorWidget(scheme);
    }
  }

  Widget _errorWidget(ColorScheme scheme) => Center(
        child: Text(
          'Não foi possível carregar a imagem.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
}

String _inferContentType(String name, {String? fallback}) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
  return 'image/jpeg';
}
