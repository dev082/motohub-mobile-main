import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/models/carroceria.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/services/carroceria_service.dart';
import 'package:motohub/services/storage_upload_service.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/attachment_pickers.dart';
import 'package:provider/provider.dart';

/// Screen for creating/editing a trailer
class CarroceriaFormScreen extends StatefulWidget {
  final Carroceria? carroceria;

  const CarroceriaFormScreen({super.key, this.carroceria});

  @override
  State<CarroceriaFormScreen> createState() => _CarroceriaFormScreenState();
}

class _CarroceriaFormScreenState extends State<CarroceriaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final CarroceriaService _carroceriaService = CarroceriaService();
  final StorageUploadService _uploadService = const StorageUploadService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _placaController;
  late TextEditingController _tipoController;
  late TextEditingController _marcaController;
  late TextEditingController _modeloController;
  late TextEditingController _anoController;
  late TextEditingController _renavamController;
  late TextEditingController _capacidadeKgController;
  late TextEditingController _capacidadeM3Controller;
  late TextEditingController _ufController;
  late TextEditingController _anttRntrcController;

  List<XFile> _pickedFotos = [];
  PickedBinaryFile? _documentoCarroceria;
  PickedBinaryFile? _comprovanteEndereco;

  bool _ativo = true;
  bool _isLoading = false;

  bool get _isEditMode => widget.carroceria != null;

  static const List<String> _ufs = [
    'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
  ];

  @override
  void initState() {
    super.initState();
    final carroceria = widget.carroceria;
    _placaController = TextEditingController(text: carroceria?.placa ?? '');
    _tipoController = TextEditingController(text: carroceria?.tipo ?? '');
    _marcaController = TextEditingController(text: carroceria?.marca ?? '');
    _modeloController = TextEditingController(text: carroceria?.modelo ?? '');
    _anoController = TextEditingController(text: carroceria?.ano?.toString() ?? '');
    _renavamController = TextEditingController(text: carroceria?.renavam ?? '');
    _capacidadeKgController = TextEditingController(text: carroceria?.capacidadeKg?.toString() ?? '');
    _capacidadeM3Controller = TextEditingController(text: carroceria?.capacidadeM3?.toString() ?? '');
    _ufController = TextEditingController(text: carroceria?.uf ?? '');
    _anttRntrcController = TextEditingController(text: carroceria?.anttRntrc ?? '');

    if (carroceria != null) {
      _ativo = carroceria.ativo;
    }
  }

  @override
  void dispose() {
    _placaController.dispose();
    _tipoController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _renavamController.dispose();
    _capacidadeKgController.dispose();
    _capacidadeM3Controller.dispose();
    _ufController.dispose();
    _anttRntrcController.dispose();
    super.dispose();
  }

  Future<void> _pickFotos() async {
    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      setState(() => _pickedFotos = [..._pickedFotos, ...files]);
    } catch (e) {
      debugPrint('Pick fotos carroceria error: $e');
    }
  }

  Future<void> _pickDocumentoCarroceria() async {
    try {
      final file = await pickDocumentFile();
      if (file == null) return;
      setState(() => _documentoCarroceria = file);
    } catch (e) {
      debugPrint('Pick documento carroceria error: $e');
    }
  }

  Future<void> _pickComprovanteEndereco() async {
    try {
      final file = await pickDocumentFile();
      if (file == null) return;
      setState(() => _comprovanteEndereco = file);
    } catch (e) {
      debugPrint('Pick comprovante endereco carroceria error: $e');
    }
  }

  Future<List<String>> _uploadFotos({required String carroceriaId, required String motoristaId}) async {
    if (_pickedFotos.isEmpty) return const [];
    final urls = <String>[];
    for (final file in _pickedFotos) {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
      final safeExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      final path = '$motoristaId/$carroceriaId/fotos/$fileName';
      final contentType = safeExt == 'png'
          ? 'image/png'
          : safeExt == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final url = await _uploadService.uploadPublic(
        bucket: StorageUploadService.trailerBucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      urls.add(url);
    }
    return urls;
  }

  Future<String?> _uploadDocumento({
    required String carroceriaId,
    required String motoristaId,
    required PickedBinaryFile? file,
    required String folder,
  }) async {
    if (file == null) return null;
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$motoristaId/$carroceriaId/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    return _uploadService.uploadPublic(
      bucket: StorageUploadService.documentsBucket,
      path: path,
      bytes: file.bytes,
      contentType: file.contentType,
    );
  }

  bool _validateAttachments() {
    final existingFotos = widget.carroceria?.fotosUrls ?? const [];
    if (_pickedFotos.isEmpty && existingFotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione as fotos da carroceria (obrigatório).')));
      return false;
    }
    if (_documentoCarroceria == null && (widget.carroceria?.documentoCarroceriaUrl == null || widget.carroceria!.documentoCarroceriaUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anexe o documento atual da carroceria (obrigatório).')));
      return false;
    }
    return true;
  }

  Future<void> _saveCarroceria() async {
    if (!_formKey.currentState!.validate()) return;

    final motorista = context.read<AppProvider>().currentMotorista;
    if (motorista == null) return;

    if (!_validateAttachments()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'motorista_id': motorista.id,
        'placa': _placaController.text.trim().toUpperCase(),
        'tipo': _tipoController.text.trim(),
        'marca': _marcaController.text.trim().isEmpty ? null : _marcaController.text.trim(),
        'modelo': _modeloController.text.trim().isEmpty ? null : _modeloController.text.trim(),
        'ano': _anoController.text.trim().isEmpty ? null : int.tryParse(_anoController.text.trim()),
        'renavam': _renavamController.text.trim().isEmpty ? null : _renavamController.text.trim(),
        'capacidade_kg': _capacidadeKgController.text.trim().isEmpty ? null : double.tryParse(_capacidadeKgController.text.trim()),
        'capacidade_m3': _capacidadeM3Controller.text.trim().isEmpty ? null : double.tryParse(_capacidadeM3Controller.text.trim()),
        'uf': _ufController.text.trim().isEmpty ? null : _ufController.text.trim().toUpperCase(),
        'antt_rntrc': _anttRntrcController.text.trim().isEmpty ? null : _anttRntrcController.text.trim(),
        'ativo': _ativo,
      };

      final carroceria = _isEditMode
          ? await _carroceriaService.updateCarroceria(widget.carroceria!.id, data)
          : await _carroceriaService.createCarroceria(data);

      if (carroceria == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar carroceria')));
        }
        return;
      }

      final uploadedFotos = await _uploadFotos(carroceriaId: carroceria.id, motoristaId: motorista.id);
      final documentoUrl = await _uploadDocumento(
        carroceriaId: carroceria.id,
        motoristaId: motorista.id,
        file: _documentoCarroceria,
        folder: 'documento_carroceria',
      );
      final comprovanteUrl = await _uploadDocumento(
        carroceriaId: carroceria.id,
        motoristaId: motorista.id,
        file: _comprovanteEndereco,
        folder: 'comprovante_endereco',
      );

      final mergedFotos = [...(widget.carroceria?.fotosUrls ?? const []), ...uploadedFotos];
      final attachmentUpdates = <String, dynamic>{};
      if (mergedFotos.isNotEmpty) {
        attachmentUpdates['fotos_urls'] = mergedFotos;
        attachmentUpdates['foto_url'] = mergedFotos.first;
      }
      if (documentoUrl != null) attachmentUpdates['documento_carroceria_url'] = documentoUrl;
      if (comprovanteUrl != null) attachmentUpdates['comprovante_endereco_proprietario_url'] = comprovanteUrl;
      if (attachmentUpdates.isNotEmpty) {
        await _carroceriaService.updateCarroceria(carroceria.id, attachmentUpdates);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Carroceria atualizada' : 'Carroceria criada')),
        );
        context.pop(true);
      }
    } catch (e) {
      debugPrint('Save carroceria error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motoristaUf = context.watch<AppProvider>().currentMotorista?.uf;
    final selectedUf = _ufController.text.trim().toUpperCase();
    final showUfWarning = motoristaUf != null && motoristaUf.trim().isNotEmpty && selectedUf.isNotEmpty && motoristaUf.trim().toUpperCase() != selectedUf;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Carroceria' : 'Nova Carroceria'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingMd,
          children: [
            if (showUfWarning) ...[
              _UfWarningBanner(motoristaUf: motoristaUf!, veiculoUf: selectedUf),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _placaController,
              decoration: const InputDecoration(
                labelText: 'Placa *',
                hintText: 'ABC1234',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) => value?.trim().isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _tipoController,
              decoration: const InputDecoration(
                labelText: 'Tipo *',
                hintText: 'Baú, Graneleira, Sider...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value?.trim().isEmpty ?? true ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _marcaController,
              decoration: const InputDecoration(
                labelText: 'Marca',
                hintText: 'Randon, Librelato, Guerra...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _modeloController,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _anoController,
              decoration: const InputDecoration(
                labelText: 'Ano',
                hintText: '2020',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _renavamController,
              decoration: const InputDecoration(
                labelText: 'RENAVAM',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _capacidadeKgController,
              decoration: const InputDecoration(
                labelText: 'Capacidade (kg)',
                hintText: '10000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _capacidadeM3Controller,
              decoration: const InputDecoration(
                labelText: 'Capacidade (m³)',
                hintText: '30',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            DropdownButtonFormField<String>(
              value: _ufs.contains(_ufController.text.trim().toUpperCase())
                  ? _ufController.text.trim().toUpperCase()
                  : null,
              decoration: const InputDecoration(
                labelText: 'UF da carroceria',
                border: OutlineInputBorder(),
              ),
              items: _ufs.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
              onChanged: (value) => setState(() => _ufController.text = value ?? ''),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _anttRntrcController,
              decoration: const InputDecoration(
                labelText: 'ANTT/RNTRC',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            PhotoGridPicker(
              title: 'Fotos da carroceria',
              required: true,
              subtitle: 'Anexe fotos externas (vários ângulos) e detalhes importantes.',
              files: _pickedFotos,
              onAdd: _pickFotos,
              onRemoveAt: (i) => setState(() => _pickedFotos.removeAt(i)),
            ),
            if (_isEditMode && (widget.carroceria?.fotosUrls ?? const []).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _ExistingPhotosGrid(urls: widget.carroceria!.fotosUrls),
            ],
            const SizedBox(height: AppSpacing.md),

            DocumentPickerTile(
              title: 'Documento atual da carroceria',
              required: true,
              subtitle: 'Anexo obrigatório do documento atual (CRLV / documento do implemento).',
              file: _documentoCarroceria,
              onPick: _pickDocumentoCarroceria,
              onClear: () => setState(() => _documentoCarroceria = null),
            ),
            const SizedBox(height: AppSpacing.md),
            DocumentPickerTile(
              title: 'Comprovante de endereço do proprietário',
              subtitle: 'Recomendado para análise do cadastro.',
              file: _comprovanteEndereco,
              onPick: _pickComprovanteEndereco,
              onClear: () => setState(() => _comprovanteEndereco = null),
            ),
            const SizedBox(height: AppSpacing.md),

            SwitchListTile(
              title: const Text('Carroceria Ativa'),
              value: _ativo,
              onChanged: (value) => setState(() => _ativo = value),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isLoading ? null : _saveCarroceria,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditMode ? 'Atualizar Carroceria' : 'Criar Carroceria'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UfWarningBanner extends StatelessWidget {
  final String motoristaUf;
  final String veiculoUf;

  const _UfWarningBanner({required this.motoristaUf, required this.veiculoUf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Motorista ($motoristaUf) e implemento ($veiculoUf) são de estados diferentes. Não é recomendado, mas você pode prosseguir.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingPhotosGrid extends StatelessWidget {
  final List<String> urls;

  const _ExistingPhotosGrid({required this.urls});

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
          Text('Fotos já cadastradas', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: urls.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            itemBuilder: (context, index) {
              final url = urls[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

