import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants/storage_keys.dart';
import '../core/result/result.dart';
import '../models/user.dart';
import '../services/secure_storage_service.dart';
import 'base_repository.dart';

class AuthRepository extends BaseRepository {
  static const _tag = 'AuthRepository';

  /// Returns `null` (in Success) when no session is saved — that's not an
  /// error, just a logged-out state.
  Future<Result<({User user, String token})?>> restoreSession() {
    return guard(() async {
      final token = await SecureStorageService.getToken();
      final userJson = await SecureStorageService.getUserData();
      if (token == null || userJson == null) return null;

      final user = User.fromJson(jsonDecode(userJson));
      await ApiService.setToken(token);
      return (user: user, token: token);
    }, tag: _tag);
  }

  Future<Result<({User user, String token})>> login({
    required String username,
    required String password,
  }) async {
    return guard(() async {
      final response = await ApiService.login(username, password);
      final outcome = fromLegacyResponse(response);
      return outcome.when(
        success: (data) async {
          final userJson = Map<String, dynamic>.from(data['user']);
          userJson['role'] ??= 'admin';
          userJson['userType'] ??= userJson['role'];
          final user = User.fromJson(userJson);
          await _persistSession(user, data['token'] as String, fallbackType: 'admin');
          return (user: user, token: data['token'] as String);
        },
        failure: (e) => throw e,
      );
    }, tag: _tag);
  }

  Future<Result<({User user, String token})>> studentLogin({
    required String studentId,
    required String password,
    bool isFirstLogin = false,
  }) async {
    return guard(() async {
      final response =
          await ApiService.studentLogin(studentId, password, isFirstLogin);
      final outcome = fromLegacyResponse(response);
      return outcome.when(
        success: (data) async {
          final json = Map<String, dynamic>.from(data['student']);
          json['role'] = 'student';
          json['userType'] = 'student';
          json['username'] ??= json['student_id']?.toString();
          final user = User.fromJson(json);
          await _persistSession(user, data['token'] as String, fallbackType: 'student');
          return (user: user, token: data['token'] as String);
        },
        failure: (e) => throw e,
      );
    }, tag: _tag);
  }

  Future<Result<({User user, String token})>> doctorLogin({
    required String username,
    required String password,
  }) async {
    return guard(() async {
      final response = await ApiService.doctorLogin(username, password);
      final outcome = fromLegacyResponse(response);
      return outcome.when(
        success: (data) async {
          final json = Map<String, dynamic>.from(data['user']);
          final user = User.fromJson(json);
          await _persistSession(user, data['token'] as String, fallbackType: 'doctor');
          return (user: user, token: data['token'] as String);
        },
        failure: (e) => throw e,
      );
    }, tag: _tag);
  }

  /// Returns the refreshed user, or `null` if nothing changed / role
  /// doesn't need refresh (e.g. TAs keep their cached snapshot).
  Future<Result<User?>> refreshUser({
    required User current,
    required String token,
  }) {
    return guard(() async {
      if (current.isTeachingAssistant) return null;

      Map<String, dynamic>? fresh;
      if (current.isDoctor) {
        final list = await ApiService.getDoctors();
        final raw = list.firstWhere(
          (d) => d['id'] == current.id,
          orElse: () => null,
        );
        if (raw != null) {
          fresh = {
            'id': raw['id'],
            'username': raw['username'],
            'name': raw['name'],
            'email': raw['email'],
            'role': 'doctor',
            'userType': 'doctor',
          };
        }
      } else {
        final list = await ApiService.getStudents();
        final raw = list.firstWhere(
          (s) => s['id'] == current.id,
          orElse: () => null,
        );
        if (raw != null) {
          fresh = {
            'id': raw['id'],
            'username': raw['student_id'],
            'name': raw['name'],
            'role': 'student',
            'userType': 'student',
            'level': raw['level'],
            'department': raw['department'],
            'academic_year': raw['academic_year'],
          };
        }
      }

      if (fresh == null) return null;
      final updated = User.fromJson(fresh);
      await SecureStorageService.saveUserData(jsonEncode(updated.toJson()));
      return updated;
    }, tag: _tag);
  }

  Future<Result<void>> logout() {
    return guard(() async {
      await SecureStorageService.clearAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.userType);
      await ApiService.setToken(null);
    }, tag: _tag);
  }

  Future<void> _persistSession(
    User user,
    String token, {
    required String fallbackType,
  }) async {
    await SecureStorageService.saveUserData(jsonEncode(user.toJson()));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.userType,
      user.userType ?? fallbackType,
    );
  }
}
