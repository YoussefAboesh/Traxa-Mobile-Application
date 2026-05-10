// lib/cubit/auth/auth_cubit.dart
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import '../../services/websocket_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthState.initial()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final userData = prefs.getString(AppConstants.userDataKey);

    if (token != null && userData != null) {
      try {
        final userJson = jsonDecode(userData);
        final user = User.fromJson(userJson);
        ApiService.setToken(token);
        emit(AuthState.success(user, token));
        await WebSocketService.instance.connect();
      } catch (e) {
        emit(AuthState.error('Failed to restore session'));
      }
    } else {
      emit(AuthState.initial());
    }
  }

  Future<void> login({
    required String username,
    required String password,
    required bool isStudent,
  }) async {
    emit(AuthState.loading());

    try {
      final response = isStudent
          ? await ApiService.studentLogin(username, password, false)
          : await ApiService.doctorLogin(username, password);

      if (response['success'] == true) {
        final token = response['token'];
        final Map<String, dynamic> userJson =
            Map<String, dynamic>.from(response[isStudent ? 'student' : 'user']);

        // Preserve role/userType from the server (e.g. 'teaching-assistant');
        // only fall back to a default if the server omitted them.
        if (isStudent) {
          userJson['role'] = 'student';
          userJson['userType'] = 'student';
        } else {
          userJson['role'] ??= 'doctor';
          userJson['userType'] ??= userJson['role'];
        }

        final user = User.fromJson(userJson);

        ApiService.setToken(token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token as String);
        await prefs.setString(
            AppConstants.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString(AppConstants.userTypeKey,
            user.userType ?? (isStudent ? 'student' : 'doctor'));

        emit(AuthState.success(user, token));

        await WebSocketService.instance.connect();
      } else {
        emit(AuthState.error(response['error'] ?? 'Login failed'));
      }
    } catch (e) {
      emit(AuthState.error('Connection error: ${e.toString()}'));
    }
  }

  Future<void> studentLogin({
    required String studentId,
    required String password,
    bool isFirstLogin = false,
  }) async {
    emit(AuthState.loading());

    try {
      final response =
          await ApiService.studentLogin(studentId, password, isFirstLogin);

      if (response['success'] == true) {
        final token = response['token'];
        final Map<String, dynamic> studentJson =
            Map<String, dynamic>.from(response['student']);

        studentJson['role'] = 'student';
        studentJson['userType'] = 'student';

        final user = User.fromJson(studentJson);

        ApiService.setToken(token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token as String);
        await prefs.setString(
            AppConstants.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString(AppConstants.userTypeKey, 'student');

        emit(AuthState.success(user, token));

        await WebSocketService.instance.connect();
      } else {
        emit(AuthState.error(response['error'] ?? 'Login failed'));
      }
    } catch (e) {
      emit(AuthState.error('Connection error: ${e.toString()}'));
    }
  }

  Future<void> doctorLogin({
    required String username,
    required String password,
  }) async {
    emit(AuthState.loading());

    try {
      final response = await ApiService.doctorLogin(username, password);

      if (response['success'] == true) {
        final token = response['token'];
        final Map<String, dynamic> userJson =
            Map<String, dynamic>.from(response['user']);

        final user = User.fromJson(userJson);

        ApiService.setToken(token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token as String);
        await prefs.setString(
            AppConstants.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString(AppConstants.userTypeKey, 'doctor');

        emit(AuthState.success(user, token));

        await WebSocketService.instance.connect();
      } else {
        emit(AuthState.error(response['error'] ?? 'Login failed'));
      }
    } catch (e) {
      emit(AuthState.error('Connection error: ${e.toString()}'));
    }
  }

  /// Replaces the cached user's permissions in-place. Used when a WebSocket
  /// event tells us the supervising doctor changed this TA's permissions —
  /// every widget reading `authState.user.permissions` will rebuild.
  Future<void> updateUserPermissions(Map<String, dynamic> newPerms) async {
    final user = state.user;
    final token = state.token;
    if (user == null || token == null) return;

    final updated = User(
      id: user.id,
      username: user.username,
      name: user.name,
      email: user.email,
      role: user.role,
      userType: user.userType,
      supervisorDoctorId: user.supervisorDoctorId,
      supervisorDoctorName: user.supervisorDoctorName,
      taId: user.taId,
      permissions: Map<String, dynamic>.from(newPerms),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.userDataKey, jsonEncode(updated.toJson()));

    emit(AuthState.success(updated, token));
    print('🔄 User permissions updated in AuthCubit');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userDataKey);
    await prefs.remove(AppConstants.userTypeKey);

    ApiService.setToken(null);
    WebSocketService.instance.disconnect();
    emit(AuthState.loggedOut());
  }

  // ✅ دالة لتحديث بيانات المستخدم من السيرفر
  Future<void> refreshUserData() async {
    if (state.user == null || state.token == null) return;

    print('🔄 Refreshing user data from server...');

    // 🚫 Never re-resolve TAs against students.json — their numeric id can
    // collide with a real student id and silently flip the session into a
    // student session. Just keep the in-memory user as-is.
    if (state.user!.isTeachingAssistant) {
      print('ℹ️ Skipping refresh for teaching-assistant — keeping cached user');
      return;
    }

    try {
      final token = state.token!;
      final userId = state.user!.id;
      final isDoctor = state.user!.isDoctor;

      Map<String, dynamic>? freshUserData;

      if (isDoctor) {
        final response = await ApiService.getDoctors();
        final doctor = response.firstWhere(
          (d) => d['id'] == userId,
          orElse: () => null,
        );
        if (doctor != null) {
          freshUserData = {
            'id': doctor['id'],
            'username': doctor['username'],
            'name': doctor['name'],
            'email': doctor['email'],
            'role': 'doctor',
            'userType': 'doctor',
          };
        }
      } else {
        final response = await ApiService.getStudents();
        final student = response.firstWhere(
          (s) => s['id'] == userId,
          orElse: () => null,
        );
        if (student != null) {
          freshUserData = {
            'id': student['id'],
            'username': student['student_id'],
            'name': student['name'],
            'role': 'student',
            'userType': 'student',
            'level': student['level'],
            'department': student['department'],
            'academic_year': student['academic_year'],
          };
        }
      }
      
      if (freshUserData != null) {
        final updatedUser = User.fromJson(freshUserData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userDataKey, jsonEncode(updatedUser.toJson()));
        
        emit(AuthState.success(updatedUser, token));
        
        print('✅ User data refreshed successfully');
      }
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    }
  }
}