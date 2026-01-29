import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hubfrete/models/chat.dart';
import 'package:hubfrete/models/entrega.dart';
import 'package:hubfrete/providers/app_provider.dart';
import 'package:hubfrete/services/chat_service.dart';
import 'package:hubfrete/services/entrega_service.dart';
import 'package:hubfrete/supabase/supabase_config.dart';
import 'package:hubfrete/theme.dart';
import 'package:hubfrete/widgets/attachment_pickers.dart';
import 'package:hubfrete/widgets/chat_attachment_preview.dart';
import 'package:hubfrete/widgets/chat_details_sheet.dart';
import 'package:hubfrete/services/storage_upload_service.dart';
import 'package:hubfrete/utils/app_error_reporter.dart';
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

  PickedBinaryFile? _pendingAttachment;

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
    return status == StatusEntrega.entregue ||
        status == StatusEntrega.cancelada;
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
      AppErrorReporter.report(context, e, operation: 'abrir chat');
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
          _messages = [..._messages, m]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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

        final last = _messages.isNotEmpty
            ? _messages.last.createdAt
            : DateTime.fromMillisecondsSinceEpoch(0);
        final newOnes = await _chatService.getMessagesAfter(chatId, last);
        if (!mounted) return;
        if (newOnes.isEmpty) return;

        final existingIds = _messages.map((e) => e.id).toSet();
        final merged = [
          ..._messages,
          ...newOnes.where((m) => !existingIds.contains(m.id))
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
        const SnackBar(
            content:
                Text('Esta entrega já foi finalizada. O chat está bloqueado.')),
      );
      return;
    }

    final text = _composer.text.trim();
    final pending = _pendingAttachment;
    if (text.isEmpty && pending == null) return;

    final chat = _chat;
    final motorista = context.read<AppProvider>().currentMotorista;
    final authUid = SupabaseConfig.client.auth.currentUser?.id;
    if (chat == null || motorista == null) return;
    if (authUid == null) {
      debugPrint(
          'Chat send blocked: user is not authenticated (authUid null).');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você não está autenticado.')));
      return;
    }

    setState(() => _isSending = true);
    try {
      String? anexoUrl;
      String? anexoNome;
      String? anexoTipo;
      int? anexoTamanho;

      if (pending != null) {
        anexoNome = pending.name;
        anexoTipo = pending.contentType;
        anexoTamanho = pending.bytes.length;
        anexoUrl = await const StorageUploadService().uploadChatAttachment(
          chatId: chat.id,
          bytes: pending.bytes,
          fileName: pending.name,
          contentType: pending.contentType ?? 'application/octet-stream',
        );
      }

      // Always use auth.uid() for RLS policy, not motorista.id.
      debugPrint(
          'Sending message as authUid=$authUid, motoristaId=${motorista.id}, motoristaUserId=${motorista.userId}');
      final msg = await _chatService.sendMessage(
        chatId: chat.id,
        senderId: authUid,
        senderNome: motorista.nomeCompleto,
        senderTipo: TipoParticipante.motorista,
        conteudo: text,
        anexoUrl: anexoUrl,
        anexoNome: anexoNome,
        anexoTipo: anexoTipo,
        anexoTamanho: anexoTamanho,
      );

      if (!mounted) return;
      if (msg == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível enviar.')));
        return;
      }

      _composer.clear();
      if (_pendingAttachment != null) setState(() => _pendingAttachment = null);
      final alreadyExists = _messages.any((x) => x.id == msg.id);
      if (!alreadyExists) {
        setState(() => _messages = [..._messages, msg]);
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send chat message error: $e');
      if (!mounted) return;
      AppErrorReporter.report(context, e, operation: 'enviar mensagem');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openAttachSheet() async {
    if (_isEntregaFinalizada) return;
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<PickedBinaryFile?>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anexar arquivo', style: context.textStyles.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Envie uma foto (PNG/JPG/WEBP) ou PDF. Os anexos são salvos no bucket chat-anexos organizados por conversa.',
                style: context.textStyles.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.photo_camera_outlined, color: theme.colorScheme.primary),
                title: const Text('Tirar foto'),
                onTap: () async {
                  try {
                    final file = await pickCameraPhotoFile();
                    if (!context.mounted) return;
                    context.pop(file);
                  } catch (e) {
                    debugPrint('pickCameraPhotoFile error: $e');
                    if (!context.mounted) return;
                    context.pop(null);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.upload_file, color: theme.colorScheme.primary),
                title: const Text('Escolher arquivo (PDF ou imagem)'),
                onTap: () async {
                  try {
                    final file = await pickDocumentFile();
                    if (!context.mounted) return;
                    context.pop(file);
                  } catch (e) {
                    debugPrint('pickDocumentFile error: $e');
                    if (!context.mounted) return;
                    context.pop(null);
                  }
                },
              ),
              if (_pendingAttachment != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.pop(null),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar'),
                ),
              ]
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (result == null) return;
    setState(() => _pendingAttachment = result);
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
      appBar: _ChatTopBar(
        title: title,
        subtitle: subtitle,
        onOpenDetails: () {
          final entrega = _entrega;
          final chat = _chat;
          if (entrega == null || chat == null) return;
          showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            builder: (_) => ChatDetailsSheet(entrega: entrega, chat: chat),
          );
        },
      ),
      body: ColoredBox(
        color: Theme.of(context).brightness == Brightness.dark ? ChatColors.darkChatBackground : ChatColors.lightChatBackground,
        child: _isLoading
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
                        child: _ChatMessageList(
                          controller: _scrollController,
                          messages: _messages,
                        ),
                      ),
                      _ChatComposerBar(
                        controller: _composer,
                        isSending: _isSending,
                        isReadOnly: isReadOnly,
                        pendingAttachment: _pendingAttachment,
                        onClearAttachment: () => setState(() => _pendingAttachment = null),
                        onOpenAttachment: _openAttachSheet,
                        onSend: _send,
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
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

class _ChatComposerBar extends StatelessWidget {
  const _ChatComposerBar({
    required this.controller,
    required this.isSending,
    required this.isReadOnly,
    required this.pendingAttachment,
    required this.onClearAttachment,
    required this.onOpenAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isReadOnly;
  final PickedBinaryFile? pendingAttachment;
  final VoidCallback onClearAttachment;
  final VoidCallback onOpenAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingAttachment != null) ...[
              _PendingAttachmentPill(
                fileName: pendingAttachment!.name,
                onClear: (!isReadOnly && !isSending) ? onClearAttachment : null,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: (!isReadOnly && !isSending) ? onOpenAttachment : null,
                  icon: Icon(Icons.add, color: scheme.onSurfaceVariant),
                  tooltip: 'Anexar',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            enabled: !isReadOnly && !isSending,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSend(),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: isReadOnly ? 'Chat finalizado' : 'Digite uma mensagem...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 46,
                  width: 46,
                  child: IconButton.filled(
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
                        : Icon(Icons.send_rounded, color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingAttachmentPill extends StatelessWidget {
  const _PendingAttachmentPill({required this.fileName, required this.onClear});

  final String fileName;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
              tooltip: 'Remover anexo',
            ),
        ],
      ),
    );
  }
}

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({
    required this.controller,
    required this.messages,
  });

  final ScrollController controller;
  final List<Mensagem> messages;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    DateTime? lastDay;

    for (final m in messages) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || !_isSameDay(day, lastDay!)) {
        children.add(_DatePill(date: day));
        children.add(const SizedBox(height: AppSpacing.sm));
        lastDay = day;
      }
      children.add(_ChatMessageBubble(message: m));
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      children: children,
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pillBg = Theme.of(context).brightness == Brightness.dark
        ? ChatColors.darkDatePill
        : ChatColors.lightDatePill;
    final textColor = scheme.onSurfaceVariant;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = _isSameDay(date, today) ? 'HOJE' : _formatDatePt(date);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 1),
        decoration: BoxDecoration(
          color: pillBg.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: context.textStyles.labelSmall
              ?.copyWith(color: textColor, letterSpacing: 0.8),
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message});

  final Mensagem message;

  static String? _resolveAttachmentUrl(Mensagem m, String? legacyFile) {
    final direct = m.anexoUrl;
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    if (legacyFile == null || legacyFile.trim().isEmpty) return null;

    // Formato legado: conteúdo era `@arquivo.ext` sem URL gravada.
    // Tentamos resolver pelo padrão atual: bucket chat-anexos/{chatId}/{arquivo}
    // Se o nome já contiver "/", usamos como path direto.
    final file = legacyFile.trim();
    final path = file.contains('/') ? file : '${m.chatId}/$file';
    try {
      return SupabaseConfig.client.storage.from(StorageUploadService.chatAttachmentsBucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('Chat: failed to resolve legacy attachment url for $path: $e');
      return null;
    }
  }

  static String? _guessContentType(String? fileName) {
    if (fileName == null) return null;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = message.senderTipo == TipoParticipante.motorista;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDriver
        ? (isDark ? ChatColors.darkOutgoingBubble : ChatColors.lightOutgoingBubble)
        : (isDark ? ChatColors.darkIncomingBubble : ChatColors.lightIncomingBubble);
    final fg = isDriver ? scheme.onSurface : scheme.onSurface;
    final timeColor = scheme.onSurfaceVariant;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isDriver ? 18 : 6),
      bottomRight: Radius.circular(isDriver ? 6 : 18),
    );

    final time = _formatTime(message.createdAt);
    final ticks = isDriver
        ? Icon(
            message.lida ? Icons.done_all : Icons.done,
            size: 16,
            color: message.lida ? scheme.primary : scheme.onSurfaceVariant,
          )
        : null;

    final legacyFile = message.legacyAttachmentFileName;
    final resolvedAttachmentUrl = _resolveAttachmentUrl(message, legacyFile);
    final resolvedAttachmentName = (message.anexoNome != null && message.anexoNome!.trim().isNotEmpty)
        ? message.anexoNome!.trim()
        : legacyFile;
    final resolvedAttachmentType = (message.anexoTipo != null && message.anexoTipo!.trim().isNotEmpty)
        ? message.anexoTipo!.trim()
        : _guessContentType(resolvedAttachmentName);

    final hasAttachment = resolvedAttachmentUrl != null && resolvedAttachmentUrl.trim().isNotEmpty;
    // Se for o formato legado `@arquivo.ext`, não mostramos o texto do "@...".
    final hasText = message.conteudo.trim().isNotEmpty && !(message.isLegacyAttachmentOnly && legacyFile != null);

    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasAttachment) ...[
                ChatAttachmentPreview(
                  url: resolvedAttachmentUrl!,
                  fileName: resolvedAttachmentName,
                  contentType: resolvedAttachmentType,
                  sizeBytes: message.anexoTamanho,
                ),
                if (hasText) const SizedBox(height: 10) else const SizedBox(height: 6),
              ],
              if (hasText) ...[
                Text(
                  message.conteudo,
                  style: context.textStyles.bodyMedium?.copyWith(color: fg, height: 1.35),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: context.textStyles.labelSmall
                        ?.copyWith(color: timeColor.withValues(alpha: 0.8)),
                  ),
                  if (ticks != null) ...[
                    const SizedBox(width: 4),
                    ticks,
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatTopBar({
    required this.title,
    required this.subtitle,
    required this.onOpenDetails,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onOpenDetails;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Icon(Icons.arrow_back, color: scheme.onSurface),
        tooltip: 'Voltar',
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: onOpenDetails,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(Icons.person_outline, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
      actions: [
        const SizedBox(width: 8),
      ],
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatDatePt(DateTime dt) {
  const months = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ'
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final mon = months[dt.month - 1];
  return '$day $mon';
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
            Icon(Icons.chat_bubble_outline,
                size: 76, color: Theme.of(context).colorScheme.outline),
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
              icon: Icon(Icons.refresh,
                  color: Theme.of(context).colorScheme.onPrimary),
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
