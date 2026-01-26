import 'package:flutter/foundation.dart';
import 'package:motohub/models/chat.dart';
import 'package:motohub/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing chat and messages
class ChatService {
  /// Get or create chat for entrega
  Future<Chat?> getChatByEntregaId(String entregaId) async {
    try {
      final data = await SupabaseConfig.client
          .from('chats')
          .select()
          .eq('entrega_id', entregaId)
          .maybeSingle();

      if (data == null) return null;
      return Chat.fromJson(data);
    } catch (e) {
      debugPrint('Get chat by entrega error: $e');
      return null;
    }
  }

  /// Get messages for chat
  Future<List<Mensagem>> getMessages(String chatId) async {
    try {
      final data = await SupabaseConfig.client
          .from('mensagens')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      return (data as List).map((json) => Mensagem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get messages error: $e');
      return [];
    }
  }

  /// Get the latest message for an entrega (used for chat list preview).
  Future<Mensagem?> getLatestMessageForEntrega(String entregaId) async {
    try {
      final chat = await getChatByEntregaId(entregaId);
      if (chat == null) return null;

      final data = await SupabaseConfig.client
          .from('mensagens')
          .select()
          .eq('chat_id', chat.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return Mensagem.fromJson(data);
    } catch (e) {
      debugPrint('Get latest message for entrega error: $e');
      return null;
    }
  }

  /// Get messages after a timestamp (used for fallback polling).
  Future<List<Mensagem>> getMessagesAfter(String chatId, DateTime after) async {
    try {
      final data = await SupabaseConfig.client
          .from('mensagens')
          .select()
          .eq('chat_id', chatId)
          .gt('created_at', after.toIso8601String())
          .order('created_at', ascending: true);

      return (data as List).map((json) => Mensagem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Get messages after error: $e');
      return [];
    }
  }

  /// Send message
  Future<Mensagem?> sendMessage({
    required String chatId,
    required String senderId,
    required String senderNome,
    required TipoParticipante senderTipo,
    required String conteudo,
  }) async {
    try {
      final authUid = SupabaseConfig.client.auth.currentUser?.id;
      debugPrint('ChatService.sendMessage senderId=$senderId authUid=$authUid senderTipo=${senderTipo.value}');
      final data = await SupabaseConfig.client
          .from('mensagens')
          .insert({
            'chat_id': chatId,
            'sender_id': senderId,
            'sender_nome': senderNome,
            'sender_tipo': senderTipo.value,
            'conteudo': conteudo,
            'lida': false,
          })
          .select()
          .single();

      // Update chat updated_at
      await SupabaseConfig.client
          .from('chats')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', chatId);

      return Mensagem.fromJson(data);
    } catch (e) {
      debugPrint('Send message error: $e');
      return null;
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId, String userId) async {
    try {
      await SupabaseConfig.client
          .from('mensagens')
          .update({'lida': true})
          .eq('chat_id', chatId)
          .neq('sender_id', userId);
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  /// Subscribe to message changes (Realtime).
  ///
  /// Note: For true realtime to work, the `mensagens` table must have Realtime
  /// enabled in Supabase (Database → Replication / Realtime).
  RealtimeChannel subscribeToMessages({
    required String chatId,
    required void Function(Mensagem message) onInsert,
    void Function(Mensagem message)? onUpdate,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    final channel = SupabaseConfig.client.channel('mensagens:$chatId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'mensagens',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: chatId),
      callback: (payload) {
        try {
          final m = Mensagem.fromJson(payload.newRecord);
          onInsert(m);
        } catch (e) {
          debugPrint('Realtime insert parse error: $e');
        }
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'mensagens',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: chatId),
      callback: (payload) {
        final cb = onUpdate;
        if (cb == null) return;
        try {
          final m = Mensagem.fromJson(payload.newRecord);
          cb(m);
        } catch (e) {
          debugPrint('Realtime update parse error: $e');
        }
      },
    );

    channel.subscribe((status, error) {
      debugPrint('Realtime subscribe mensagens:$chatId status=$status error=$error');
      onStatus?.call(status, error);
    });

    return channel;
  }

  /// Unsubscribe from realtime channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await SupabaseConfig.client.removeChannel(channel);
  }

  /// Get unread message count
  Future<int> getUnreadCount(String chatId, String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('mensagens')
          .select('id')
          .eq('chat_id', chatId)
          .eq('lida', false)
          .neq('sender_id', userId);

      return (data as List).length;
    } catch (e) {
      debugPrint('Get unread count error: $e');
      return 0;
    }
  }
}
