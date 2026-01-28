import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/chat.dart';
import 'package:hubfrete/models/entrega.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/chat_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/chat_conversation_card.dart';
import 'package:provider/provider.dart';

/// Chat history screen - shows chats for delivered/cancelled deliveries (read-only)
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final EntregaService _entregaService = EntregaService();
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  List<Entrega> _entregasFinalizadas = [];

  final Map<String, Future<Mensagem?>> _lastMessageFuturesByEntregaId = {};

  @override
  void initState() {
    super.initState();
    _loadHistorico();
  }

  Future<void> _loadHistorico() async {
    setState(() => _isLoading = true);
    try {
      final motorista = context.read<AppProvider>().currentMotorista;
      if (motorista == null) return;

      final entregas = await _entregaService.getMotoristaEntregas(motorista.id);
      final finalizadas = entregas
          .where((e) => e.status == StatusEntrega.entregue || e.status == StatusEntrega.cancelada)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (!mounted) return;
      setState(() {
        _entregasFinalizadas = finalizadas;
        _lastMessageFuturesByEntregaId.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar histórico: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de chats'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entregasFinalizadas.isEmpty
              ? _EmptyHistoricoState(onReload: _loadHistorico)
              : RefreshIndicator(
                  onRefresh: _loadHistorico,
                  child: ListView.builder(
                    padding: AppSpacing.paddingMd,
                    itemCount: _entregasFinalizadas.length,
                    itemBuilder: (context, index) {
                      final entrega = _entregasFinalizadas[index];

                      final lastMessageFuture = _lastMessageFuturesByEntregaId.putIfAbsent(
                        entrega.id,
                        () => _chatService.getLatestMessageForEntrega(entrega.id),
                      );

                      return ChatConversationCard(
                        entrega: entrega,
                        lastMessageFuture: lastMessageFuture,
                        leadingIcon: Icons.history,
                        onTap: () => context.push('/chat/${entrega.id}'),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyHistoricoState extends StatelessWidget {
  const _EmptyHistoricoState({required this.onReload});

  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history,
                size: 76, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sem histórico ainda',
              style: context.textStyles.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Quando uma entrega for concluída ou cancelada, o chat aparecerá aqui (somente leitura).',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => onReload(),
              icon: Icon(Icons.refresh,
                  color: Theme.of(context).colorScheme.onPrimary),
              label: Text(
                'Recarregar',
                style: context.textStyles.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
