import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/chat.dart';
import 'package:hubfrete/models/entrega.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/chat_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/app_drawer.dart';
import 'package:hubfrete/widgets/chat_conversation_card.dart';
import 'package:hubfrete/widgets/chat_section.dart';
import 'package:hubfrete/widgets/pull_to_refresh.dart';
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

  bool _expandedAguardandoColeta = true;
  bool _expandedEmTransito = true;

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
            child: _HistoryPillButton(onPressed: () => context.push('/chat/historico')),
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
                      itemCount: 1,
                      itemBuilder: (context, index) => _ChatSectionsList(
                        entregas: _entregasComChat,
                        expandedAguardandoColeta: _expandedAguardandoColeta,
                        expandedEmTransito: _expandedEmTransito,
                        onToggleAguardandoColeta: () => setState(() => _expandedAguardandoColeta = !_expandedAguardandoColeta),
                        onToggleEmTransito: () => setState(() => _expandedEmTransito = !_expandedEmTransito),
                        buildChatItem: (entrega) => _buildChatItem(context, entrega),
                      ),
                    ),
            ),
    );
  }

  Widget _buildChatItem(BuildContext context, Entrega entrega) {
    final lastMessageFuture = _lastMessageFuturesByEntregaId.putIfAbsent(
      entrega.id,
      () => _chatService.getLatestMessageForEntrega(entrega.id),
    );

    final ({Color accent, IconData icon}) style = switch (entrega.status) {
      StatusEntrega.saiuParaEntrega => (accent: StatusColors.waiting, icon: Icons.local_shipping_outlined),
      StatusEntrega.saiuParaColeta || StatusEntrega.aguardando => (accent: StatusColors.collected, icon: Icons.folder_outlined),
      StatusEntrega.problema => (accent: Theme.of(context).colorScheme.error, icon: Icons.report_gmailerrorred_outlined),
      StatusEntrega.cancelada => (accent: Theme.of(context).colorScheme.error, icon: Icons.cancel_outlined),
      StatusEntrega.entregue => (accent: Theme.of(context).colorScheme.primary, icon: Icons.check_circle_outline),
    };

    return ChatConversationCard(
      entrega: entrega,
      lastMessageFuture: lastMessageFuture,
      onTap: () => context.push('/chat/${entrega.id}'),
      accentColor: style.accent,
      leadingIcon: style.icon,
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

class _HistoryPillButton extends StatelessWidget {
  const _HistoryPillButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.history, color: scheme.primary, size: 18),
      label: Text(
        'Histórico',
        style: context.textStyles.labelLarge?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _ChatSectionsList extends StatelessWidget {
  const _ChatSectionsList({
    required this.entregas,
    required this.expandedAguardandoColeta,
    required this.expandedEmTransito,
    required this.onToggleAguardandoColeta,
    required this.onToggleEmTransito,
    required this.buildChatItem,
  });

  final List<Entrega> entregas;
  final bool expandedAguardandoColeta;
  final bool expandedEmTransito;
  final VoidCallback onToggleAguardandoColeta;
  final VoidCallback onToggleEmTransito;
  final Widget Function(Entrega entrega) buildChatItem;

  @override
  Widget build(BuildContext context) {
    final aguardando = <Entrega>[];
    final emTransito = <Entrega>[];
    final outros = <Entrega>[];

    for (final e in entregas) {
      switch (e.status) {
        case StatusEntrega.aguardando:
        case StatusEntrega.saiuParaColeta:
          aguardando.add(e);
          break;
        case StatusEntrega.saiuParaEntrega:
          emTransito.add(e);
          break;
        default:
          outros.add(e);
      }
    }

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aguardando.isNotEmpty)
          ChatSection(
            title: 'Aguardando coleta',
            count: aguardando.length,
            expanded: expandedAguardandoColeta,
            onToggle: onToggleAguardandoColeta,
            children: aguardando.map(buildChatItem).toList(),
          ),
        if (aguardando.isNotEmpty && emTransito.isNotEmpty) const SizedBox(height: AppSpacing.md),
        if (emTransito.isNotEmpty)
          ChatSection(
            title: 'Em trânsito',
            count: emTransito.length,
            expanded: expandedEmTransito,
            onToggle: onToggleEmTransito,
            children: emTransito.map(buildChatItem).toList(),
          ),
        if (outros.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ...outros.map(buildChatItem),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Outras entregas concluídas estão no Histórico.',
          style: context.textStyles.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
