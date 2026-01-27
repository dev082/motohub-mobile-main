import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:motohub/models/checklist_veiculo.dart';
import 'package:motohub/services/storage_upload_service.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:provider/provider.dart';

/// Bottom sheet para preencher checklist do veículo antes de iniciar entrega
class ChecklistVeiculoSheet extends StatefulWidget {
  final Function(ChecklistVeiculo) onSubmit;

  const ChecklistVeiculoSheet({super.key, required this.onSubmit});

  @override
  State<ChecklistVeiculoSheet> createState() => _ChecklistVeiculoSheetState();
}

class _ChecklistVeiculoSheetState extends State<ChecklistVeiculoSheet> {
  bool _pneusOk = false;
  bool _freiosOk = false;
  bool _lucesOk = false;
  bool _documentosOk = false;
  bool _limpezaOk = false;
  final List<String> _fotosUrls = [];
  final _observacoesController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  bool get _todosOk => _pneusOk && _freiosOk && _lucesOk && _documentosOk && _limpezaOk;

  Future<void> _adicionarFoto() async {
    setState(() => _isUploading = true);
    try {
      final motoristaId = context.read<AppProvider>().currentMotorista?.id;
      if (motoristaId == null || motoristaId.isEmpty) {
        throw Exception('Motorista não autenticado');
      }

      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) {
        setState(() => _isUploading = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final url = await const StorageUploadService().uploadChecklistPhoto(
        motoristaId: motoristaId,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      setState(() {
        _fotosUrls.add(url);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar foto: $e')),
        );
      }
    }
  }

  void _removerFoto(int index) {
    setState(() => _fotosUrls.removeAt(index));
  }

  void _confirmar() {
    if (!_todosOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos os itens do checklist')),
      );
      return;
    }

    if (_fotosUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos uma foto do veículo')),
      );
      return;
    }

    final checklist = ChecklistVeiculo(
      pneusOk: _pneusOk,
      freiosOk: _freiosOk,
      lucesOk: _lucesOk,
      documentosOk: _documentosOk,
      limpezaOk: _limpezaOk,
      fotosVeiculoUrls: _fotosUrls,
      observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
      timestamp: DateTime.now(),
    );

    widget.onSubmit(checklist);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text('Checklist do Veículo', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Verifique as condições do veículo antes de iniciar', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 20),
            _buildCheckItem(
              label: 'Pneus em bom estado',
              value: _pneusOk,
              onChanged: (v) => setState(() => _pneusOk = v),
            ),
            _buildCheckItem(
              label: 'Freios funcionando',
              value: _freiosOk,
              onChanged: (v) => setState(() => _freiosOk = v),
            ),
            _buildCheckItem(
              label: 'Luzes funcionando',
              value: _lucesOk,
              onChanged: (v) => setState(() => _lucesOk = v),
            ),
            _buildCheckItem(
              label: 'Documentos do veículo',
              value: _documentosOk,
              onChanged: (v) => setState(() => _documentosOk = v),
            ),
            _buildCheckItem(
              label: 'Veículo limpo e organizado',
              value: _limpezaOk,
              onChanged: (v) => setState(() => _limpezaOk = v),
            ),
            const Divider(height: 32),
            Text('Fotos do Veículo *', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_fotosUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fotosUrls
                    .asMap()
                    .entries
                    .map((entry) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(entry.value, height: 80, width: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => _removerFoto(entry.key),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _adicionarFoto,
              icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo),
              label: Text(_isUploading ? 'Enviando...' : 'Adicionar Foto'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observacoesController,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _todosOk && _fotosUrls.isNotEmpty ? _confirmar : null,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Confirmar e Iniciar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem({required String label, required bool value, required Function(bool) onChanged}) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
