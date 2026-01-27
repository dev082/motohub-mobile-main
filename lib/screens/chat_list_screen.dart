import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/models/chat.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/services/chat_service.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/theme.dart';
import 'package:motohub/widgets/app_drawer.dart';
import 'package:motohub/widgets/chat_conversation_card.dart';
import 'package:motohub/widgets/pull_to_refresh.dart';
import 'package:provider/provider.dart';

/// Chat list screen - shows chats for active deliveries
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final EntregaService _entregaService = EntregaService();
  final ChatService _chatService = ChatService();
  List<Entrega> _entregasComChat = [];
  bool _isLoading = true;

  final Map<String, Future<Mensagem?>> _lastMessageFuturesByEntregaId = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final motorista = context.read<AppProvider>().currentMotorista;
      if (motorista == null) return;

      // Get active deliveries (chats are created for all deliveries)
      final entregas = await _entregaService.getMotoristaEntregas(
        motorista.id,
        activeOnly: true,
      );

      setState(() {
        _entregasComChat = entregas;
        _lastMessageFuturesByEntregaId.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar chats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(activeRoute: GoRouterState.of(context).matchedLocation),
      appBar: AppBar(
        title: const Text('Conversas'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton.icon(
              onPressed: () => context.push('/chat/historico'),
              icon: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
              label: Text(
                'Histórico',
                style: context.textStyles.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PullToRefresh(
              onRefresh: _loadChats,
              child: _entregasComChat.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.paddingMd,
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: _buildEmptyState(),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.paddingMd,
                      itemCount: _entregasComChat.length,
                      itemBuilder: (context, index) {
                        final entrega = _entregasComChat[index];
                        return _buildChatItem(context, entrega);
                      },
                    ),
            ),
    );
  }

  Widget _buildChatItem(BuildContext context, Entrega entrega) {
    final lastMessageFuture = _lastMessageFuturesByEntregaId.putIfAbsent(
      entrega.id,
      () => _chatService.getLatestMessageForEntrega(entrega.id),
    );

    return ChatConversationCard(
      entrega: entrega,
      lastMessageFuture: lastMessageFuture,
      onTap: () => context.push('/chat/${entrega.id}'),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhuma conversa ativa',
            style: context.textStyles.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sem entregas em andamento agora.\nUse “Histórico” para ver conversas antigas.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
