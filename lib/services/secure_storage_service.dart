// lib/services/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
  // Storage keys for sensitive data
  static const String _tokenKey = 'auth_token_secure';
  static const String _userDataKey = 'user_data_secure';
  static const String _refreshTokenKey = 'refresh_token_secure';

  // ================== TOKEN MANAGEMENT ==================

  /// Save auth token securely (encrypted)
  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      print('🔐 Token saved securely (encrypted)');
    } catch (e) {
      print('❌ Error saving token to secure storage: $e');
      rethrow;
    }
  }

  /// Get auth token from secure storage
  static Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        print('🔑 Token retrieved from secure storage');
      }
      return token;
    } catch (e) {
      print('❌ Error reading token from secure storage: $e');
      return null;
    }
  }

  /// Check if token exists
  static Future<bool> hasToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('❌ Error checking token existence: $e');
      return false;
    }
  }

  /// Delete auth token securely
  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      print('🔐 Token deleted from secure storage');
    } catch (e) {
      print('❌ Error deleting token: $e');
      rethrow;
    }
  }

  // ================== USER DATA ==================

  /// Save user data securely (encrypted)
  static Future<void> saveUserData(String userData) async {
    try {
      await _storage.write(key: _userDataKey, value: userData);
      print('🔐 User data saved securely (encrypted)');
    } catch (e) {
      print('❌ Error saving user data to secure storage: $e');
      rethrow;
    }
  }

  /// Get user data from secure storage
  static Future<String?> getUserData() async {
    try {
      final userData = await _storage.read(key: _userDataKey);
      if (userData != null) {
        print('📦 User data retrieved from secure storage');
      }
      return userData;
    } catch (e) {
      print('❌ Error reading user data from secure storage: $e');
      return null;
    }
  }

  /// Delete user data securely
  static Future<void> deleteUserData() async {
    try {
      await _storage.delete(key: _userDataKey);
      print('🔐 User data deleted from secure storage');
    } catch (e) {
      print('❌ Error deleting user data: $e');
      rethrow;
    }
  }

  // ================== REFRESH TOKEN ==================

  /// Save refresh token securely (encrypted)
  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
      print('🔐 Refresh token saved securely (encrypted)');
    } catch (e) {
      print('❌ Error saving refresh token: $e');
      rethrow;
    }
  }

  /// Get refresh token from secure storage
  static Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _refreshTokenKey);
      if (token != null) {
        print('🔑 Refresh token retrieved from secure storage');
      }
      return token;
    } catch (e) {
      print('❌ Error reading refresh token: $e');
      return null;
    }
  }

  /// Delete refresh token securely
  static Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
      print('🔐 Refresh token deleted from secure storage');
    } catch (e) {
      print('❌ Error deleting refresh token: $e');
      rethrow;
    }
  }

  // ================== CLEAR ALL ==================

  /// Clear all sensitive data from secure storage
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      print('🔐 All sensitive data cleared from secure storage');
    } catch (e) {
      print('❌ Error clearing secure storage: $e');
      rethrow;
    }
  }
}
