import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/nav.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/attachment_pickers.dart';
import 'package:motohub/widgets/app_drawer.dart';
import 'package:motohub/widgets/canhoto_upload_sheet.dart';
import 'package:motohub/widgets/entrega_card.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entregas screen - shows motorista's deliveries
class EntregasScreen extends StatefulWidget {
  const EntregasScreen({super.key});

  @override
  State<EntregasScreen> createState() => _EntregasScreenState();
}

class _EntregasScreenState extends State<EntregasScreen> with SingleTickerProviderStateMixin {
  final EntregaService _entregaService = EntregaService();
  late TabController _tabController;
  RealtimeChannel? _entregasChannel;
  String? _realtimeMotoristaId;
  final Set<String> _updatingEntregaIds = {};
  
  List<Entrega> _entregasAtivas = [];
  List<Entrega> _entregasHistorico = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEntregas();
  }

  @override
  void dispose() {
    _stopRealtime();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startRealtime(String motoristaId) async {
    if (_realtimeMotoristaId == motoristaId && _entregasChannel != null) return;
    await _stopRealtime();

    _realtimeMotoristaId = motoristaId;
    final channel = SupabaseConfig.client.channel('entregas:motorista:$motoristaId');
    _entregasChannel = channel;

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'entregas',
      callback: (payload) {
        final record = payload.newRecord;
        final id = record['id'] as String?;
        final mid = record['motorista_id'] as String?;
        if (id == null || mid != motoristaId) return;
        final updated = Entrega.fromJson(Map<String, dynamic>.from(record));
        if (!mounted) return;
        setState(() => _upsertEntrega(updated));
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'entregas',
      callback: (payload) {
        final record = payload.newRecord;
        final id = record['id'] as String?;
        final mid = record['motorista_id'] as String?;
        if (id == null || mid != motoristaId) return;
        final inserted = Entrega.fromJson(Map<String, dynamic>.from(record));
        if (!mounted) return;
        setState(() => _upsertEntrega(inserted));
      },
    );

    channel.subscribe((status, error) {
      debugPrint('Realtime entregas status=$status error=$error');
    });
  }

  Future<void> _stopRealtime() async {
    try {
      final ch = _entregasChannel;
      if (ch != null) await SupabaseConfig.client.removeChannel(ch);
    } catch (e) {
      debugPrint('Stop realtime entregas error: $e');
    } finally {
      _entregasChannel = null;
      _realtimeMotoristaId = null;
    }
  }

  void _upsertEntrega(Entrega entrega) {
    bool isActive(StatusEntrega s) => [
          StatusEntrega.aguardando,
          StatusEntrega.saiuParaColeta,
          StatusEntrega.saiuParaEntrega,
        ].contains(s);

    final inAtivasIndex = _entregasAtivas.indexWhere((e) => e.id == entrega.id);
    final inHistoricoIndex = _entregasHistorico.indexWhere((e) => e.id == entrega.id);

    if (isActive(entrega.status)) {
      if (inHistoricoIndex != -1) _entregasHistorico.removeAt(inHistoricoIndex);
      if (inAtivasIndex != -1) {
        _entregasAtivas[inAtivasIndex] = entrega;
      } else {
        _entregasAtivas.insert(0, entrega);
      }
    } else {
      if (inAtivasIndex != -1) _entregasAtivas.removeAt(inAtivasIndex);
      if (inHistoricoIndex != -1) {
        _entregasHistorico[inHistoricoIndex] = entrega;
      } else {
        _entregasHistorico.insert(0, entrega);
      }
    }
  }

  StatusEntrega? _nextStatus(StatusEntrega current) {
    switch (current) {
      case StatusEntrega.aguardando:
        return StatusEntrega.saiuParaColeta;
      case StatusEntrega.saiuParaColeta:
        return StatusEntrega.saiuParaEntrega;
      case StatusEntrega.saiuParaEntrega:
        return StatusEntrega.entregue;
      case StatusEntrega.entregue:
      case StatusEntrega.problema:
      case StatusEntrega.cancelada:
        return null;
    }
  }

  Future<void> _advanceStage(Entrega entrega) async {
    final next = _nextStatus(entrega.status);
    if (next == null) return;

    setState(() => _updatingEntregaIds.add(entrega.id));
    try {
      if (next == StatusEntrega.entregue) {
        final ok = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => CanhotoUploadSheet(
            onSubmit: (PickedBinaryFile file) async {
              await _entregaService.uploadComprovante(
                entrega.id,
                originalFileName: file.name,
                fileBytes: file.bytes,
                contentType: file.contentType,
              );
              await _entregaService.updateStatus(entrega.id, next);
            },
          ),
        );
        if (ok != true) return;
      } else {
        await _entregaService.updateStatus(entrega.id, next);
      }
      // Otimismo: atualiza localmente; o realtime deve confirmar depois.
      if (!mounted) return;
      setState(() => _upsertEntrega(entrega.copyWith(status: next, updatedAt: DateTime.now())));
    } catch (e) {
      debugPrint('Advance stage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível atualizar o status: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingEntregaIds.remove(entrega.id));
    }
  }

  Future<void> _loadEntregas() async {
    setState(() => _isLoading = true);
    try {
      final app = context.read<AppProvider>();
      final motorista = app.currentMotorista;
      if (motorista == null) return;

      await _startRealtime(motorista.id);

      final todasEntregas = await _entregaService.getMotoristaEntregas(motorista.id);
      
      setState(() {
        _entregasAtivas = todasEntregas.where((e) => [
          StatusEntrega.aguardando,
          StatusEntrega.saiuParaColeta,
          StatusEntrega.saiuParaEntrega,
        ].contains(e.status)).toList();

        _entregasHistorico = todasEntregas.where((e) => [
          StatusEntrega.entregue,
          StatusEntrega.problema,
          StatusEntrega.cancelada,
        ].contains(e.status)).toList();

        _isLoading = false;
      });

      // Garante que exista uma “entrega ativa” selecionada quando há mais de uma.
      final activeId = app.activeEntregaId;
      final hasSelected = activeId != null && _entregasAtivas.any((e) => e.id == activeId);
      if (_entregasAtivas.isNotEmpty && !hasSelected) {
        await app.setActiveEntregaId(_entregasAtivas.first.id);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar entregas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(activeRoute: GoRouterState.of(context).matchedLocation),
      appBar: AppBar(
        title: const Text('Minhas Entregas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ativas'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntregas,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEntregasList(
                    _entregasAtivas,
                    isEmpty: 'Você não tem entregas ativas',
                  ),
                  _buildEntregasList(
                    _entregasHistorico,
                    isEmpty: 'Nenhuma entrega no histórico',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEntregasList(
    List<Entrega> entregas, {
    required String isEmpty,
  }) {
    if (entregas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isEmpty,
              style: context.textStyles.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.paddingMd,
      itemCount: entregas.length,
      itemBuilder: (context, index) {
        final entrega = entregas[index];
        final app = context.watch<AppProvider>();
        final isSelected = app.activeEntregaId == entrega.id;
        return EntregaCard(
          entrega: entrega,
          // Tap no card abre o mapa em tela cheia para analisar a rota.
          onTap: () => context.push(AppRoutes.entregaMapaPath(entrega.id)),
          isSelected: isSelected,
          onSelect: () => app.setActiveEntregaId(entrega.id),
          onAdvanceStage: () => _advanceStage(entrega),
          isAdvancing: _updatingEntregaIds.contains(entrega.id),
        );
      },
    );
  }
}
