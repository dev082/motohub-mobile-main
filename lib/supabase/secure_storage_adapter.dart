import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Adapter para usar flutter_secure_storage com Supabase
/// 
/// Implementa a interface LocalStorage do Supabase para armazenar
/// tokens JWT de forma segura usando flutter_secure_storage
class SecureStorageAdapter extends LocalStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    webOptions: WebOptions(
      dbName: 'motohub_auth',
      publicKey: 'motohub_auth_key',
    ),
  );

  @override
  Future<void> initialize() async {
    // Inicialização não é necessária para flutter_secure_storage
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: supabasePersistSessionKey).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('SecureStorageAdapter.accessToken error: $e');
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.containsKey(key: supabasePersistSessionKey).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('SecureStorageAdapter.hasAccessToken error: $e');
      return false;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(
        key: supabasePersistSessionKey,
        value: persistSessionString,
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('SecureStorageAdapter.persistSession error: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: supabasePersistSessionKey).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('SecureStorageAdapter.removePersistedSession error: $e');
    }
  }
}
