import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_log.dart';

/// Android: values are encrypted with AES-GCM using a key held in the Android
/// Keystore (flutter_secure_storage 10 defaults), instead of the plain XML
/// SharedPreferences file supabase_flutter uses by default.
const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
);

/// Stores the Supabase Auth session (access + refresh token) in secure storage.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required this.persistSessionKey});

  final String persistSessionKey;

  @override
  Future<void> initialize() async {
    await _migrateLegacySession();
  }

  /// One-time move of a session saved by older builds in SharedPreferences,
  /// so existing employees stay signed in. The plaintext copy is deleted.
  Future<void> _migrateLegacySession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy == null) return;
      if (await _secureStorage.read(key: persistSessionKey) == null) {
        await _secureStorage.write(key: persistSessionKey, value: legacy);
      }
      await prefs.remove(persistSessionKey);
    } catch (error) {
      appLog('Legacy session migration failed', error.runtimeType);
    }
  }

  @override
  Future<bool> hasAccessToken() =>
      _secureStorage.containsKey(key: persistSessionKey);

  @override
  Future<String?> accessToken() => _secureStorage.read(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secureStorage.write(key: persistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() =>
      _secureStorage.delete(key: persistSessionKey);
}

/// Stores the short-lived PKCE code verifier in secure storage as well.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  const SecureGotrueAsyncStorage();

  @override
  Future<String?> getItem({required String key}) =>
      _secureStorage.read(key: key);

  @override
  Future<void> removeItem({required String key}) =>
      _secureStorage.delete(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secureStorage.write(key: key, value: value);
}
