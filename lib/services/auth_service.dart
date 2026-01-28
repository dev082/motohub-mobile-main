import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/motorista.dart';
import 'package:hubfrete/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for motorista authentication
class AuthService {
  /// Sign in with email and password (for motoristas)
  Future<Motorista?> signInMotorista(String email, String password) async {
    try {
      // Try to authenticate with Supabase Auth
      final authResponse = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        // If Supabase auth fails, try custom motorista auth
        return await _signInMotoristaCustom(email, password);
      }

      // Get motorista data
      final motoristaData = await SupabaseConfig.client
          .from('motoristas')
          .select()
          .eq('user_id', authResponse.user!.id)
          .maybeSingle();

      if (motoristaData != null) {
        return Motorista.fromJson(motoristaData);
      }

      // If no user_id match, try email match
      final motoristaByEmail = await SupabaseConfig.client
          .from('motoristas')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (motoristaByEmail != null) {
        return Motorista.fromJson(motoristaByEmail);
      }

      return null;
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.message}');
      // Try custom motorista auth as fallback
      return await _signInMotoristaCustom(email, password);
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  /// Custom authentication for motoristas (legacy system)
  Future<Motorista?> _signInMotoristaCustom(String email, String password) async {
    try {
      final motoristaData = await SupabaseConfig.client
          .from('motoristas')
          .select()
          .eq('email', email)
          .eq('senha', password)
          .eq('ativo', true)
          .maybeSingle();

      if (motoristaData == null) return null;

      final motorista = Motorista.fromJson(motoristaData);

      // Importante: os recursos críticos (ex.: tracking_sessions/locations) usam RLS
      // baseado em auth.uid(). Se o login legado não criar uma sessão Supabase Auth,
      // as inserções falham no app nativo.
      await _ensureAuthSessionForMotorista(
        email: email,
        password: password,
        motoristaId: motorista.id,
        existingUserId: motorista.userId,
      );

      // Recarrega motorista para refletir o user_id atualizado (se aplicável)
      final refreshed = await SupabaseConfig.client
          .from('motoristas')
          .select()
          .eq('id', motorista.id)
          .maybeSingle();

      return refreshed != null ? Motorista.fromJson(refreshed) : motorista;
    } catch (e) {
      debugPrint('Custom sign in error: $e');
      return null;
    }
  }

  Future<void> _ensureAuthSessionForMotorista({
    required String email,
    required String password,
    required String motoristaId,
    required String? existingUserId,
  }) async {
    try {
      final current = SupabaseConfig.auth.currentUser;
      if (current != null) {
        // Se já existe sessão e o motorista ainda não está linkado, linka.
        if (existingUserId == null || existingUserId.isEmpty) {
          await SupabaseConfig.client.from('motoristas').update({
            'user_id': current.id,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', motoristaId);
        }
        return;
      }

      // Tenta logar pelo Auth. Se não existir usuário, tenta criar.
      try {
        final authResponse = await SupabaseConfig.auth.signInWithPassword(email: email, password: password);
        final user = authResponse.user;
        if (user != null && (existingUserId == null || existingUserId.isEmpty || existingUserId != user.id)) {
          await SupabaseConfig.client.from('motoristas').update({
            'user_id': user.id,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', motoristaId);
        }
        return;
      } on AuthException catch (e) {
        // "Invalid login credentials" geralmente indica que o usuário ainda não foi criado no Auth.
        debugPrint('Auth signInWithPassword failed (will try signUp): ${e.message}');
      }

      final signUp = await SupabaseConfig.auth.signUp(email: email, password: password);
      final user = signUp.user;
      if (user != null) {
        await SupabaseConfig.client.from('motoristas').update({
          'user_id': user.id,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', motoristaId);
      } else {
        debugPrint('Auth signUp returned null user for motoristaId=$motoristaId');
      }
    } catch (e) {
      // Não quebra o login se o vínculo falhar, mas registra para diagnóstico.
      debugPrint('EnsureAuthSessionForMotorista error: $e');
    }
  }

  /// Get current motorista
  Future<Motorista?> getCurrentMotorista() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return null;

      final motoristaData = await SupabaseConfig.client
          .from('motoristas')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (motoristaData == null) return null;
      return Motorista.fromJson(motoristaData);
    } catch (e) {
      debugPrint('Get current motorista error: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await SupabaseConfig.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Update motorista profile
  Future<void> updateMotorista(String motoristaId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await SupabaseConfig.client
          .from('motoristas')
          .update(updates)
          .eq('id', motoristaId);
    } catch (e) {
      debugPrint('Update motorista error: $e');
      rethrow;
    }
  }

  /// Update push token
  Future<void> updatePushToken(String motoristaId, String pushToken) async {
    try {
      await SupabaseConfig.client
          .from('motoristas')
          .update({
            'push_token': pushToken,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', motoristaId);
    } catch (e) {
      debugPrint('Update push token error: $e');
      rethrow;
    }
  }
}
