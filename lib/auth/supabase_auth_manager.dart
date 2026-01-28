import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hubfrete/auth/auth_manager.dart';
import 'package:hubfrete/models/user.dart';
import 'package:hubfrete/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Supabase implementation of AuthManager with email/password authentication
class SupabaseAuthManager extends AuthManager with EmailSignInManager {
  @override
  Future<User?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final response = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) return null;

      // Fetch user data from users table
      final userData = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      if (userData == null) return null;
      return User.fromJson(userData);
    } on supabase.AuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  @override
  Future<User?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) return null;

      // Create user record in users table
      final userData = await SupabaseConfig.client.from('users').insert({
        'id': response.user!.id,
        'email': email,
      }).select().single();

      return User.fromJson(userData);
    } on supabase.AuthException catch (e) {
      debugPrint('Sign up error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await SupabaseConfig.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(BuildContext context) async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw Exception('No user logged in');

      // Delete user from auth (cascades to users table)
      await SupabaseConfig.client.rpc('delete_user');
    } catch (e) {
      debugPrint('Delete user error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateEmail({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await SupabaseConfig.auth.updateUser(
        supabase.UserAttributes(email: email),
      );

      // Update email in users table
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        await SupabaseConfig.client.from('users').update({
          'email': email,
        }).eq('id', userId);
      }
    } catch (e) {
      debugPrint('Update email error: $e');
      rethrow;
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  /// Get current authenticated user
  Future<User?> getCurrentUser() async {
    try {
      final authUser = SupabaseConfig.auth.currentUser;
      if (authUser == null) return null;

      final userData = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (userData == null) return null;
      return User.fromJson(userData);
    } catch (e) {
      debugPrint('Get current user error: $e');
      return null;
    }
  }

  /// Stream of auth state changes
  Stream<supabase.AuthState> get authStateChanges =>
      SupabaseConfig.auth.onAuthStateChange;
}
