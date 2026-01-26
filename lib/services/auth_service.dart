import 'package:flutter/foundation.dart';
import 'package:motohub/models/motorista.dart';
import 'package:motohub/supabase/supabase_config.dart';
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
      return Motorista.fromJson(motoristaData);
    } catch (e) {
      debugPrint('Custom sign in error: $e');
      return null;
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
