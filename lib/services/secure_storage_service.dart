// lib/services/secure_storage_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for sensitive data (auth token, user data, refresh token).
///
/// On Android it uses Jetpack `EncryptedSharedPreferences`, and on iOS the
/// Keychain (unlocked after first device unlock). Any read that fails because
/// the underlying entry was corrupted — a common case after an app reinstall
/// or OS backup restore — automatically purges the bad key so the user can
/// still recover by logging in again.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys for sensitive data
  static const String _tokenKey = 'auth_token_secure';
  static const String _userDataKey = 'user_data_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';

  // ================== INTERNAL HELPERS ==================

  static void _log(String message) {
    if (kDebugMode) print(message);
  }

  /// Writes [value] under [key]. [label] is only used for log messages.
  static Future<void> _write(String key, String value, String label) async {
    try {
      await _storage.write(key: key, value: value);
      _log('🔐 $label saved securely (encrypted)');
    } catch (e) {
      _log('❌ Error saving $label to secure storage: $e');
      rethrow;
    }
  }

  /// Reads the value stored under [key]. Returns `null` when it is missing or
  /// when the entry is corrupted — in the latter case the bad key is purged.
  static Future<String?> _read(String key, String label) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) _log('🔑 $label retrieved from secure storage');
      return value;
    } catch (e) {
      _log('❌ Error reading $label from secure storage: $e');
      // Recover from corrupted data so the user is not locked out forever.
      try {
        await _storage.delete(key: key);
        _log('🧹 Corrupted $label entry purged from secure storage');
      } catch (_) {}
      return null;
    }
  }

  /// Deletes the value stored under [key].
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

  /// Save auth token securely (encrypted).
  static Future<void> saveToken(String token) =>
      _write(_tokenKey, token, 'Token');

  /// Get auth token from secure storage.
  static Future<String?> getToken() => _read(_tokenKey, 'Token');

  /// Check if a non-empty token exists.
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Delete auth token securely.
  static Future<void> deleteToken() => _delete(_tokenKey, 'Token');

  // ================== USER DATA ==================

  /// Save user data securely (encrypted).
  static Future<void> saveUserData(String userData) =>
      _write(_userDataKey, userData, 'User data');

  /// Get user data from secure storage.
  static Future<String?> getUserData() => _read(_userDataKey, 'User data');

  /// Delete user data securely.
  static Future<void> deleteUserData() =>
      _delete(_userDataKey, 'User data');

  // ================== REFRESH TOKEN ==================

  /// Save refresh token securely (encrypted).
  static Future<void> saveRefreshToken(String token) =>
      _write(_refreshTokenKey, token, 'Refresh token');

  /// Get refresh token from secure storage.
  static Future<String?> getRefreshToken() =>
      _read(_refreshTokenKey, 'Refresh token');

  /// Delete refresh token securely.
  static Future<void> deleteRefreshToken() =>
      _delete(_refreshTokenKey, 'Refresh token');

  // ================== CLEAR ALL ==================

  /// Clear all sensitive data from secure storage.
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
