import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:motohub/models/chat.dart';
import 'package:motohub/models/entrega.dart';
import 'package:motohub/providers/app_provider.dart';
import 'package:motohub/services/chat_service.dart';
import 'package:motohub/services/entrega_service.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:motohub/theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Chat conversation screen.
///
/// Chat permite envio apenas enquanto a entrega estiver ativa.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.entregaId});

  final String entregaId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final EntregaService _entregaService = EntregaService();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;

  Entrega? _entrega;
  Chat? _chat;
  List<Mensagem> _messages = [];
  RealtimeChannel? _channel;

  Timer? _pollTimer;
  bool _realtimeReady = false;

  bool get _isEntregaFinalizada {
    final status = _entrega?.status;
    return status == StatusEntrega.entregue || status == StatusEntrega.cancelada;
  }

  @override
  void initState() {
    super.initState();
    // Mark this chat as active to avoid showing notifications while the user is inside it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().setActiveChatEntregaId(widget.entregaId);
    });
    _load();
  }

  @override
  void dispose() {
    try {
      context.read<AppProvider>().setActiveChatEntregaId(null);
    } catch (_) {
      // Provider might not be available during teardown in some edge cases.
    }
    _composer.dispose();
    _scrollController.dispose();

     _pollTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      _chatService.unsubscribe(channel);
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final entrega = await _entregaService.getEntregaById(widget.entregaId);
      final chat = await _chatService.getChatByEntregaId(widget.entregaId);

      if (!mounted) return;
      setState(() {
        _entrega = entrega;
        _chat = chat;
      });

      if (chat == null) {
        setState(() => _isLoading = false);
        return;
      }

      final motorista = context.read<AppProvider>().currentMotorista;
      final authUid = SupabaseConfig.client.auth.currentUser?.id;
      if (motorista != null && authUid != null) {
        await _chatService.markAsRead(chat.id, authUid);
      }

      final msgs = await _chatService.getMessages(chat.id);
      if (!mounted) return;

      setState(() {
        _messages = msgs;
        _isLoading = false;
      });

      _subscribe(chat.id);
      _ensureRealtimeOrPolling(chat.id);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat load error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir chat: $e')));
    }
  }

  void _subscribe(String chatId) {
    final previous = _channel;
    if (previous != null) {
      _chatService.unsubscribe(previous);
    }

    _realtimeReady = false;
    _channel = _chatService.subscribeToMessages(
      chatId: chatId,
      onInsert: (m) {
        if (!mounted) return;
        final alreadyExists = _messages.any((x) => x.id == m.id);
        if (alreadyExists) return;
        setState(() {
          _messages = [..._messages, m]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
      },
      onUpdate: (m) {
        if (!mounted) return;
        final idx = _messages.indexWhere((x) => x.id == m.id);
        if (idx == -1) return;
        setState(() {
          final next = [..._messages];
          next[idx] = m;
          _messages = next;
        });
      },
      onStatus: (status, error) {
        if (!mounted) return;
        final isReady = status == RealtimeSubscribeStatus.subscribed;
        if (_realtimeReady != isReady) setState(() => _realtimeReady = isReady);
        if (!isReady) {
          _startPolling(chatId);
        } else {
          _pollTimer?.cancel();
        }
      },
    );
  }

  void _ensureRealtimeOrPolling(String chatId) {
    // If the subscription callback doesn't reach SUBSCRIBED quickly (common on web
    // when Realtime isn't enabled or there's network issues), start polling.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (!_realtimeReady) _startPolling(chatId);
    });
  }

  void _startPolling(String chatId) {
    _pollTimer?.cancel();
    // Lightweight fallback: fetch only new messages based on the last known createdAt.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        if (!mounted) return;
        // If realtime becomes ready, stop polling.
        if (_realtimeReady) {
          _pollTimer?.cancel();
          return;
        }

        final last = _messages.isNotEmpty ? _messages.last.createdAt : DateTime.fromMillisecondsSinceEpoch(0);
        final newOnes = await _chatService.getMessagesAfter(chatId, last);
        if (!mounted) return;
        if (newOnes.isEmpty) return;

        final existingIds = _messages.map((e) => e.id).toSet();
        final merged = [..._messages, ...newOnes.where((m) => !existingIds.contains(m.id))]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        setState(() => _messages = merged);
        _scrollToBottom();
      } catch (e) {
        debugPrint('Chat polling error: $e');
      }
    });
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    if (_isEntregaFinalizada) {
      debugPrint('Chat send blocked: entrega finalizada (entregue/cancelada).');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta entrega já foi finalizada. O chat está bloqueado.')),
      );
      return;
    }

    final text = _composer.text.trim();
    if (text.isEmpty) return;

    final chat = _chat;
    final motorista = context.read<AppProvider>().currentMotorista;
    final authUid = SupabaseConfig.client.auth.currentUser?.id;
    if (chat == null || motorista == null) return;
    if (authUid == null) {
      debugPrint('Chat send blocked: user is not authenticated (authUid null).');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não está autenticado.')));
      return;
    }

    setState(() => _isSending = true);
    try {
      // Always use auth.uid() for RLS policy, not motorista.id.
      debugPrint('Sending message as authUid=$authUid, motoristaId=${motorista.id}, motoristaUserId=${motorista.userId}');
      final msg = await _chatService.sendMessage(
        chatId: chat.id,
        senderId: authUid,
        senderNome: motorista.nomeCompleto,
        senderTipo: TipoParticipante.motorista,
        conteudo: text,
      );

      if (!mounted) return;
      if (msg == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível enviar.')));
        return;
      }

      _composer.clear();
      final alreadyExists = _messages.any((x) => x.id == msg.id);
      if (!alreadyExists) {
        setState(() => _messages = [..._messages, msg]);
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send chat message error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrega = _entrega;
    final title = entrega?.codigo ?? entrega?.carga?.codigo ?? 'Chat';
    final subtitle = entrega?.carga != null
        ? '${entrega!.carga!.origem?.cidade} → ${entrega.carga!.destino?.cidade}'
        : entrega?.status.displayName;

    final isReadOnly = _isEntregaFinalizada;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(
                subtitle,
                style: context.textStyles.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chat == null
              ? _ChatNotAvailable(onRetry: _load)
              : Column(
                  children: [
                    if (!_realtimeReady)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.md, right: AppSpacing.md),
                        child: _ConnectionHint(isRealtime: _realtimeReady),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: AppSpacing.paddingMd,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          return _MessageBubble(message: m);
                        },
                      ),
                    ),
                    _ComposerBar(
                      controller: _composer,
                      isSending: _isSending,
                      isReadOnly: isReadOnly,
                      onSend: _send,
                    ),
                  ],
                ),
    );
  }
}

class _ConnectionHint extends StatelessWidget {
  const _ConnectionHint({required this.isRealtime});

  final bool isRealtime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surfaceContainerHighest;
    final fg = scheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering, color: fg, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Conectando ao tempo real… (fallback automático ativo)',
              style: context.textStyles.bodySmall?.copyWith(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.isSending,
    required this.isReadOnly,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isReadOnly;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isReadOnly && !isSending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isReadOnly ? 'Chat finalizado' : 'Digite uma mensagem…',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: (!isReadOnly && !isSending) ? onSend : null,
              icon: isSending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Icon(Icons.send, color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Mensagem message;

  @override
  Widget build(BuildContext context) {
    final isDriver = message.senderTipo == TipoParticipante.motorista;
    final scheme = Theme.of(context).colorScheme;

    final bg = isDriver ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = isDriver ? scheme.onPrimaryContainer : scheme.onSurface;

    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.senderNome,
                style: context.textStyles.labelSmall?.copyWith(color: fg.withValues(alpha: 0.75)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                message.conteudo,
                style: context.textStyles.bodyMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatNotAvailable extends StatelessWidget {
  const _ChatNotAvailable({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 76, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Chat indisponível',
              style: context.textStyles.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Não encontramos um chat para esta entrega.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
              label: Text(
                'Tentar novamente',
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