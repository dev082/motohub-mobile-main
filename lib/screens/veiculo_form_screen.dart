import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/veiculo.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/storage_upload_service.dart';
import 'package:hubfrete/services/veiculo_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/attachment_pickers.dart';
import 'package:hubfrete/utils/app_error_reporter.dart';
import 'package:provider/provider.dart';

/// Screen for creating/editing a vehicle
class VeiculoFormScreen extends StatefulWidget {
  final Veiculo? veiculo;

  const VeiculoFormScreen({super.key, this.veiculo});

  @override
  State<VeiculoFormScreen> createState() => _VeiculoFormScreenState();
}

class _VeiculoFormScreenState extends State<VeiculoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final VeiculoService _veiculoService = VeiculoService();
  final StorageUploadService _uploadService = const StorageUploadService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _placaController;
  late TextEditingController _marcaController;
  late TextEditingController _modeloController;
  late TextEditingController _anoController;
  late TextEditingController _renavamController;
  late TextEditingController _capacidadeKgController;
  late TextEditingController _capacidadeM3Controller;
  late TextEditingController _anttRntrcController;
  late TextEditingController _ufController;
  late TextEditingController _proprietarioNomeController;
  late TextEditingController _proprietarioCpfCnpjController;

  TipoVeiculo _selectedTipo = TipoVeiculo.truck;
  TipoCarroceria _selectedCarroceria = TipoCarroceria.aberta;
  TipoPropriedadeVeiculo _selectedTipoPropriedade = TipoPropriedadeVeiculo.pf;
  bool _rastreador = false;
  bool _seguroAtivo = false;
  bool _ativo = true;
  bool _isLoading = false;

  List<XFile> _pickedFotos = [];
  PickedBinaryFile? _documentoVeiculo;
  PickedBinaryFile? _comprovanteEndereco;

  bool get _isEditMode => widget.veiculo != null;

  static const List<String> _ufs = [
    'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
  ];

  @override
  void initState() {
    super.initState();
    final veiculo = widget.veiculo;
    _placaController = TextEditingController(text: veiculo?.placa ?? '');
    _marcaController = TextEditingController(text: veiculo?.marca ?? '');
    _modeloController = TextEditingController(text: veiculo?.modelo ?? '');
    _anoController = TextEditingController(text: veiculo?.ano?.toString() ?? '');
    _renavamController = TextEditingController(text: veiculo?.renavam ?? '');
    _capacidadeKgController = TextEditingController(text: veiculo?.capacidadeKg?.toString() ?? '');
    _capacidadeM3Controller = TextEditingController(text: veiculo?.capacidadeM3?.toString() ?? '');
    _anttRntrcController = TextEditingController(text: veiculo?.anttRntrc ?? '');
    _ufController = TextEditingController(text: veiculo?.uf ?? '');
    _proprietarioNomeController = TextEditingController(text: veiculo?.proprietarioNome ?? '');
    _proprietarioCpfCnpjController = TextEditingController(text: veiculo?.proprietarioCpfCnpj ?? '');

    if (veiculo != null) {
      _selectedTipo = veiculo.tipo;
      _selectedCarroceria = veiculo.carroceria;
      _rastreador = veiculo.rastreador;
      _seguroAtivo = veiculo.seguroAtivo;
      _ativo = veiculo.ativo;
      _selectedTipoPropriedade = veiculo.tipoPropriedade ?? TipoPropriedadeVeiculo.pf;
    }
  }

  @override
  void dispose() {
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _renavamController.dispose();
    _capacidadeKgController.dispose();
    _capacidadeM3Controller.dispose();
    _anttRntrcController.dispose();
    _ufController.dispose();
    _proprietarioNomeController.dispose();
    _proprietarioCpfCnpjController.dispose();
    super.dispose();
  }

  Future<void> _pickFotos() async {
    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      setState(() => _pickedFotos = [..._pickedFotos, ...files]);
    } catch (e) {
      debugPrint('Pick photos error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível selecionar as fotos.')));
      }
    }
  }

  Future<void> _pickDocumentoVeiculo() async {
    try {
      final file = await pickDocumentFile();
      if (file == null) return;
      setState(() => _documentoVeiculo = file);
    } catch (e) {
      debugPrint('Pick documento veiculo error: $e');
    }
  }

  Future<void> _pickComprovanteEndereco() async {
    try {
      final file = await pickDocumentFile();
      if (file == null) return;
      setState(() => _comprovanteEndereco = file);
    } catch (e) {
      debugPrint('Pick comprovante endereco error: $e');
    }
  }

  Future<List<String>> _uploadFotos({required String veiculoId, required String motoristaId}) async {
    if (_pickedFotos.isEmpty) return const [];

    final urls = <String>[];
    for (final file in _pickedFotos) {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
      final safeExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      final path = '$motoristaId/$veiculoId/fotos/$fileName';
      final contentType = safeExt == 'png'
          ? 'image/png'
          : safeExt == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final url = await _uploadService.uploadPublic(
        bucket: StorageUploadService.vehicleBucket,
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      urls.add(url);
    }
    return urls;
  }

  Future<String?> _uploadDocumento({
    required String veiculoId,
    required String motoristaId,
    required PickedBinaryFile? file,
    required String folder,
  }) async {
    if (file == null) return null;
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$motoristaId/$veiculoId/$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    return _uploadService.uploadPublic(
      bucket: StorageUploadService.documentsBucket,
      path: path,
      bytes: file.bytes,
      contentType: file.contentType,
    );
  }

  bool _validateAttachments({required bool isPf}) {
    final existingFotos = widget.veiculo?.fotosUrls ?? const [];
    if (_pickedFotos.isEmpty && existingFotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione as fotos do veículo (obrigatório).')));
      return false;
    }
    if (!isPf) return true;
    // PF requirements
    if (_documentoVeiculo == null && (widget.veiculo?.documentoVeiculoUrl == null || widget.veiculo!.documentoVeiculoUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anexe o documento atual do veículo (CRLV).')));
      return false;
    }
    if (_comprovanteEndereco == null && (widget.veiculo?.comprovanteEnderecoProprietarioUrl == null || widget.veiculo!.comprovanteEnderecoProprietarioUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anexe o comprovante de endereço do proprietário.')));
      return false;
    }
    return true;
  }

  Future<void> _saveVeiculo() async {
    if (!_formKey.currentState!.validate()) return;

    final motorista = context.read<AppProvider>().currentMotorista;
    if (motorista == null) return;

    final isPf = _selectedTipoPropriedade == TipoPropriedadeVeiculo.pf;
    if (!_validateAttachments(isPf: isPf)) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'motorista_id': motorista.id,
        'placa': _placaController.text.trim().toUpperCase(),
        'tipo': _selectedTipo.value,
        'carroceria': _selectedCarroceria.value,
        'marca': _marcaController.text.trim().isEmpty ? null : _marcaController.text.trim(),
        'modelo': _modeloController.text.trim().isEmpty ? null : _modeloController.text.trim(),
        'ano': _anoController.text.trim().isEmpty ? null : int.tryParse(_anoController.text.trim()),
        'renavam': _renavamController.text.trim().isEmpty ? null : _renavamController.text.trim(),
        'capacidade_kg': _capacidadeKgController.text.trim().isEmpty ? null : double.tryParse(_capacidadeKgController.text.trim()),
        'capacidade_m3': _capacidadeM3Controller.text.trim().isEmpty ? null : double.tryParse(_capacidadeM3Controller.text.trim()),
        'antt_rntrc': _anttRntrcController.text.trim().isEmpty ? null : _anttRntrcController.text.trim(),
        'tipo_propriedade': _selectedTipoPropriedade.value,
        'uf': _ufController.text.trim().isEmpty ? null : _ufController.text.trim().toUpperCase(),
        'proprietario_nome': _proprietarioNomeController.text.trim().isEmpty ? null : _proprietarioNomeController.text.trim(),
        'proprietario_cpf_cnpj': _proprietarioCpfCnpjController.text.trim().isEmpty ? null : _proprietarioCpfCnpjController.text.trim(),
        'rastreador': _rastreador,
        'seguro_ativo': _seguroAtivo,
        'ativo': _ativo,
      };

      final veiculo = _isEditMode
          ? await _veiculoService.updateVeiculo(widget.veiculo!.id, data)
          : await _veiculoService.createVeiculo(data);

      if (veiculo == null) {
        if (mounted) AppErrorReporter.report(context, Exception('Falha ao salvar veículo'), operation: 'salvar veículo');
        return;
      }

      // Upload attachments and patch record
      final uploadedFotos = await _uploadFotos(veiculoId: veiculo.id, motoristaId: motorista.id);
      final documentoUrl = await _uploadDocumento(
        veiculoId: veiculo.id,
        motoristaId: motorista.id,
        file: _documentoVeiculo,
        folder: 'documento_veiculo',
      );
      final comprovanteUrl = await _uploadDocumento(
        veiculoId: veiculo.id,
        motoristaId: motorista.id,
        file: _comprovanteEndereco,
        folder: 'comprovante_endereco',
      );

      final mergedFotos = [...(widget.veiculo?.fotosUrls ?? const []), ...uploadedFotos];
      final attachmentUpdates = <String, dynamic>{};
      if (mergedFotos.isNotEmpty) {
        attachmentUpdates['fotos_urls'] = mergedFotos;
        attachmentUpdates['foto_url'] = mergedFotos.first;
      }
      if (documentoUrl != null) attachmentUpdates['documento_veiculo_url'] = documentoUrl;
      if (comprovanteUrl != null) attachmentUpdates['comprovante_endereco_proprietario_url'] = comprovanteUrl;

      if (attachmentUpdates.isNotEmpty) {
        await _veiculoService.updateVeiculo(veiculo.id, attachmentUpdates);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Veículo atualizado' : 'Veículo criado')),
        );
        context.pop(true);
      }
    } catch (e) {
      debugPrint('Save veiculo error: $e');
      if (mounted) AppErrorReporter.report(context, e, operation: 'salvar veículo');
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
        title: Text(_isEditMode ? 'Editar Veículo' : 'Novo Veículo'),
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
            DropdownButtonFormField<TipoPropriedadeVeiculo>(
              value: _selectedTipoPropriedade,
              decoration: const InputDecoration(
                labelText: 'Propriedade do veículo *',
                border: OutlineInputBorder(),
              ),
              items: TipoPropriedadeVeiculo.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedTipoPropriedade = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _ufs.contains(_ufController.text.trim().toUpperCase())
                  ? _ufController.text.trim().toUpperCase()
                  : null,
              decoration: const InputDecoration(
                labelText: 'UF do veículo',
                border: OutlineInputBorder(),
              ),
              items: _ufs.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
              onChanged: (value) {
                setState(() => _ufController.text = value ?? '');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<TipoVeiculo>(
              value: _selectedTipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de Veículo *',
                border: OutlineInputBorder(),
              ),
              items: TipoVeiculo.values.map((tipo) {
                return DropdownMenuItem(value: tipo, child: Text(tipo.label));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedTipo = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<TipoCarroceria>(
              value: _selectedCarroceria,
              decoration: const InputDecoration(
                labelText: 'Tipo de Carroceria *',
                border: OutlineInputBorder(),
              ),
              items: TipoCarroceria.values.map((carroceria) {
                return DropdownMenuItem(value: carroceria, child: Text(carroceria.label));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedCarroceria = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _marcaController,
              decoration: const InputDecoration(
                labelText: 'Marca',
                hintText: 'Mercedes, Volvo, Scania...',
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
            TextFormField(
              controller: _anttRntrcController,
              decoration: const InputDecoration(
                labelText: 'ANTT/RNTRC',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            PhotoGridPicker(
              title: 'Fotos do veículo',
              required: true,
              subtitle: 'Obrigatório anexar fotos externas do veículo inteiro (vários ângulos).',
              files: _pickedFotos,
              onAdd: _pickFotos,
              onRemoveAt: (i) => setState(() => _pickedFotos.removeAt(i)),
            ),
            if (_isEditMode && (widget.veiculo?.fotosUrls ?? const []).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _ExistingPhotosGrid(urls: widget.veiculo!.fotosUrls),
            ],
            const SizedBox(height: AppSpacing.md),

            if (_selectedTipoPropriedade == TipoPropriedadeVeiculo.pf) ...[
              DocumentPickerTile(
                title: 'Documento atual do veículo (CRLV)',
                required: true,
                subtitle: 'Anexo obrigatório: “documento atual do veículo recebido”.',
                file: _documentoVeiculo,
                onPick: _pickDocumentoVeiculo,
                onClear: () => setState(() => _documentoVeiculo = null),
              ),
              const SizedBox(height: AppSpacing.md),
              DocumentPickerTile(
                title: 'Comprovante de endereço do proprietário',
                required: true,
                subtitle: 'Se estiver no nome de outra pessoa, será exigido comprovante de vínculo (etapa do motorista).',
                file: _comprovanteEndereco,
                onPick: _pickComprovanteEndereco,
                onClear: () => setState(() => _comprovanteEndereco = null),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _proprietarioNomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do proprietário',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _proprietarioCpfCnpjController,
                decoration: const InputDecoration(
                  labelText: 'CPF/CNPJ do proprietário',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              _PjPlaceholderCard(),
              const SizedBox(height: AppSpacing.md),
            ],

            SwitchListTile(
              title: const Text('Possui Rastreador'),
              value: _rastreador,
              onChanged: (value) => setState(() => _rastreador = value),
            ),
            SwitchListTile(
              title: const Text('Seguro Ativo'),
              value: _seguroAtivo,
              onChanged: (value) => setState(() => _seguroAtivo = value),
            ),
            SwitchListTile(
              title: const Text('Veículo Ativo'),
              value: _ativo,
              onChanged: (value) => setState(() => _ativo = value),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isLoading ? null : _saveVeiculo,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditMode ? 'Atualizar Veículo' : 'Criar Veículo'),
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
              'Motorista ($motoristaUf) e veículo ($veiculoUf) são de estados diferentes. Não é recomendado, mas você pode prosseguir.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PjPlaceholderCard extends StatelessWidget {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Fluxo de Veículo PJ está habilitado, mas os documentos/campos obrigatórios ainda estão “a definir” (conforme especificação).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
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

