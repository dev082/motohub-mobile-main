import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço de armazenamento seguro para tokens JWT do Supabase
/// 
/// Usa flutter_secure_storage para Android/iOS (armazenamento criptografado)
/// e SharedPreferences para Web (storage do navegador)
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    webOptions: WebOptions(
      dbName: 'motohub_db',
      publicKey: 'motohub_public_key',
    ),
  );

  /// Salva um valor de forma segura
  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Secure storage write error: $e');
      rethrow;
    }
  }

  /// Lê um valor armazenado
  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Secure storage read error: $e');
      return null;
    }
  }

  /// Remove um valor
  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Secure storage delete error: $e');
    }
  }

  /// Remove todos os valores
  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Secure storage deleteAll error: $e');
    }
  }

  /// Verifica se uma chave existe
  static Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('Secure storage containsKey error: $e');
      return false;
    }
  }

  /// Lista todas as chaves
  static Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      debugPrint('Secure storage readAll error: $e');
      return {};
    }
  }
}
