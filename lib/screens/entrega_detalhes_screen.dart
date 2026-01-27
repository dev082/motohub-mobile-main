import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/models/entrega_evento.dart';
import 'package:motohub/models/prova_entrega.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/services/entrega_evento_service.dart';
import 'package:motohub/services/prova_entrega_service.dart';
import 'package:motohub/widgets/attachment_pickers.dart';
import 'package:motohub/widgets/canhoto_upload_sheet.dart';
import 'package:motohub/widgets/checklist_veiculo_sheet.dart';
import 'package:motohub/widgets/entrega_timeline_widget.dart';

/// Tela de detalhes da entrega com timeline, POD e ações
class EntregaDetalhesScreen extends StatefulWidget {
  final String entregaId;

  const EntregaDetalhesScreen({super.key, required this.entregaId});

  @override
  State<EntregaDetalhesScreen> createState() => _EntregaDetalhesScreenState();
}

class _EntregaDetalhesScreenState extends State<EntregaDetalhesScreen> with SingleTickerProviderStateMixin {
  final _entregaService = EntregaService();
  final _eventoService = EntregaEventoService();
  final _provaService = ProvaEntregaService();

  late TabController _tabController;
  Entrega? _entrega;
  List<EntregaEvento> _eventos = [];
  ProvaEntrega? _prova;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDados() async {
    setState(() => _isLoading = true);
    try {
      final entrega = await _entregaService.getEntregaById(widget.entregaId);
      final eventos = await _eventoService.getEventosByEntrega(widget.entregaId);
      final prova = await _provaService.getByEntregaId(widget.entregaId);

      setState(() {
        _entrega = entrega;
        _eventos = eventos;
        _prova = prova;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes da Entrega'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Resumo'),
            Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
            Tab(icon: Icon(Icons.assignment_turned_in), text: 'POD'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entrega == null
              ? const Center(child: Text('Entrega não encontrada'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildResumoTab(),
                    _buildTimelineTab(),
                    _buildPODTab(),
                  ],
                ),
    );
  }

  Widget _buildResumoTab() {
    final carga = _entrega!.carga;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text('Informações da Entrega', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Status', _entrega!.status.displayName),
                  if (_entrega!.codigo != null) _buildInfoRow('Código', _entrega!.codigo!),
                  if (_entrega!.pesoAlocadoKg != null) _buildInfoRow('Peso', '${_entrega!.pesoAlocadoKg!.toStringAsFixed(0)} kg'),
                  if (_entrega!.valorFrete != null) _buildInfoRow('Valor Frete', 'R\$ ${_entrega!.valorFrete!.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          if (carga != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Carga', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    _buildInfoRow('Descrição', carga.descricao),
                    _buildInfoRow('Peso Total', '${carga.pesoKg.toStringAsFixed(0)} kg'),
                    if (carga.origem != null) _buildInfoRow('Origem', '${carga.origem!.cidade} - ${carga.origem!.estado}'),
                    if (carga.destino != null) _buildInfoRow('Destino', '${carga.destino!.cidade} - ${carga.destino!.estado}'),
                  ],
                ),
              ),
            ),
          ],
          if (_entrega!.checklistVeiculo != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text('Checklist do Veículo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildChecklistItem('Pneus', _entrega!.checklistVeiculo!.pneusOk),
                    _buildChecklistItem('Freios', _entrega!.checklistVeiculo!.freiosOk),
                    _buildChecklistItem('Luzes', _entrega!.checklistVeiculo!.lucesOk),
                    _buildChecklistItem('Documentos', _entrega!.checklistVeiculo!.documentosOk),
                    _buildChecklistItem('Limpeza', _entrega!.checklistVeiculo!.limpezaOk),
                    if (_entrega!.checklistVeiculo!.fotosVeiculoUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Fotos do Veículo', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _entrega!.checklistVeiculo!.fotosVeiculoUrls
                            .map((url) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url, height: 80, width: 80, fit: BoxFit.cover),
                                ))
                            .toList(),
                      ),
                    ],
                    if (_entrega!.checklistVeiculo!.observacoes != null) ...[
                      const SizedBox(height: 12),
                      Text('Observações:', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_entrega!.checklistVeiculo!.observacoes!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildAcoesRapidas(),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return RefreshIndicator(
      onRefresh: _loadDados,
      child: _eventos.isEmpty
          ? const Center(child: Text('Nenhum evento registrado'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: EntregaTimelineWidget(eventos: _eventos),
            ),
    );
  }

  Widget _buildPODTab() {
    if (_prova == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('POD não registrado', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('A prova de entrega será registrada ao finalizar', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navegar para tela de captura de POD
              },
              icon: const Icon(Icons.add),
              label: const Text('Criar POD'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recebedor', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  _buildInfoRow('Nome', _prova!.nomeRecebedor),
                  if (_prova!.documentoRecebedor != null) _buildInfoRow('Documento', _prova!.documentoRecebedor!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Checklist', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  _buildChecklistItem('Avarias Constatadas', !_prova!.checklist.avariasConstatadas),
                  _buildChecklistItem('Lacre Intacto', _prova!.checklist.lacreIntacto),
                  _buildChecklistItem('Quantidade Conferida', _prova!.checklist.quantidadeConferida),
                  _buildChecklistItem('Nota Fiscal Presente', _prova!.checklist.notaFiscalPresente),
                ],
              ),
            ),
          ),
          if (_prova!.assinaturaUrl != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assinatura', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_prova!.assinaturaUrl!, height: 150, width: double.infinity, fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_prova!.fotosUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fotos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _prova!.fotosUrls
                          .map((url) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(url, height: 100, width: 100, fit: BoxFit.cover),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcoesRapidas() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ações Rápidas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_entrega!.status == StatusEntrega.aguardando)
                  ElevatedButton.icon(onPressed: () => _mudarStatus(StatusEntrega.saiuParaColeta), icon: const Icon(Icons.play_arrow), label: const Text('Sair para coleta')),
                if (_entrega!.status == StatusEntrega.saiuParaColeta)
                  ElevatedButton.icon(onPressed: () => _mudarStatus(StatusEntrega.saiuParaEntrega), icon: const Icon(Icons.route), label: const Text('Sair para entrega')),
                if (_entrega!.status == StatusEntrega.saiuParaEntrega)
                  ElevatedButton.icon(onPressed: () => _finalizarEntrega(), icon: const Icon(Icons.done_all), label: const Text('Finalizar Entrega')),
                OutlinedButton.icon(onPressed: () => _reportarProblema(), icon: const Icon(Icons.error_outline), label: const Text('Reportar Problema')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _mudarStatus(StatusEntrega novoStatus) async {
    // Ao iniciar a operação (coleta/entrega), exigir checklist do veículo.
    // Se já existe checklist salvo na entrega, não pedir novamente.
    final shouldRequireChecklist =
        (novoStatus == StatusEntrega.saiuParaColeta) && (_entrega?.checklistVeiculo == null);

    if (shouldRequireChecklist) {
      final checklist = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => ChecklistVeiculoSheet(
          onSubmit: (c) => context.pop(c),
        ),
      );
      if (checklist == null) return;

      try {
        await _entregaService.updateStatus(
          widget.entregaId,
          novoStatus,
          checklistData: checklist.toJson(),
        );
        await _eventoService.createEventoFromStatus(widget.entregaId, novoStatus.value);
        await _loadDados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status atualizado para ${novoStatus.displayName}')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar status')));
        }
      }
      return;
    }

    // Para outros status, atualizar direto
    try {
      await _entregaService.updateStatus(widget.entregaId, novoStatus);
      await _eventoService.createEventoFromStatus(widget.entregaId, novoStatus.value);
      await _loadDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status atualizado para ${novoStatus.displayName}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar status')));
      }
    }
  }

  Future<void> _finalizarEntrega() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => CanhotoUploadSheet(
        onSubmit: (PickedBinaryFile file) async {
          await _entregaService.uploadComprovante(
            widget.entregaId,
            originalFileName: file.name,
            fileBytes: file.bytes,
            contentType: file.contentType,
          );
          await _mudarStatus(StatusEntrega.entregue);
        },
      ),
    );
    if (ok != true) return;
  }

  Future<void> _reportarProblema() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar Problema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Descreva o problema', border: OutlineInputBorder()),
              maxLines: 3,
              onChanged: (value) {
                // Capturar texto
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => context.pop('Problema reportado'), child: const Text('Confirmar')),
        ],
      ),
    );

    if (motivo != null && mounted) {
      await _eventoService.createEvento(entregaId: widget.entregaId, tipo: TipoEventoEntrega.problema, observacao: motivo);
      await _loadDados();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Problema reportado')));
    }
  }
}
