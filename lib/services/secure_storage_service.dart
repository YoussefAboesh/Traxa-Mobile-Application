import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/logger.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _tokenKey = 'auth_token_secure';
  static const String _userDataKey = 'user_data_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';

  // ================== INTERNAL HELPERS ==================

  static void _log(String message) {
    if (kDebugMode) logDebug(message);
  }

  static Future<void> _write(String key, String value, String label) async {
    try {
      await _storage.write(key: key, value: value);
      _log('🔐 $label saved securely (encrypted)');
    } catch (e) {
      _log('❌ Error saving $label to secure storage: $e');
      rethrow;
    }
  }

  static Future<String?> _read(String key, String label) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) _log('🔑 $label retrieved from secure storage');
      return value;
    } catch (e) {
      _log('❌ Error reading $label from secure storage: $e');
      try {
        await _storage.delete(key: key);
        _log('🧹 Corrupted $label entry purged from secure storage');
      } catch (_) {}
      return null;
    }
  }

  static Future<void> _delete(String key, String label) async {
    try {
      await _storage.delete(key: key);
      _log('🔐 $label deleted from secure storage');
    } catch (e) {
      _log('❌ Error deleting $label: $e');
      rethrow;
    }
  }

  // ================== TOKEN MANAGEMENT ==================

  static Future<void> saveToken(String token) =>
      _write(_tokenKey, token, 'Token');

  static Future<String?> getToken() => _read(_tokenKey, 'Token');

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> deleteToken() => _delete(_tokenKey, 'Token');

  // ================== USER DATA ==================

  static Future<void> saveUserData(String userData) =>
      _write(_userDataKey, userData, 'User data');

  static Future<String?> getUserData() => _read(_userDataKey, 'User data');

  static Future<void> deleteUserData() =>
      _delete(_userDataKey, 'User data');

  // ================== REFRESH TOKEN ==================

  static Future<void> saveRefreshToken(String token) =>
      _write(_refreshTokenKey, token, 'Refresh token');

  static Future<String?> getRefreshToken() =>
      _read(_refreshTokenKey, 'Refresh token');

  static Future<void> deleteRefreshToken() =>
      _delete(_refreshTokenKey, 'Refresh token');

  // ================== CLEAR ALL ==================

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      _log('🔐 All sensitive data cleared from secure storage');
    } catch (e) {
      _log('❌ Error clearing secure storage: $e');
      rethrow;
    }
  }
}
