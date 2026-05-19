import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import '../../services/websocket_service.dart';
import '../../services/secure_storage_service.dart';
import 'auth_state.dart';
import '../../core/logger.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthState.initial()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final token = await SecureStorageService.getToken();
      final userDataJson = await SecureStorageService.getUserData();

      if (token != null && userDataJson != null) {
        try {
          final userJson = jsonDecode(userDataJson);
          final user = User.fromJson(userJson);
          ApiService.setToken(token);
          emit(AuthState.success(user, token));
          await WebSocketService.instance.connect();
          logDebug('✅ Session restored from secure storage');
        } catch (e) {
          emit(AuthState.error('Failed to restore session'));
        }
      } else {
        emit(AuthState.initial());
      }
    } catch (e) {
      logDebug('❌ Error checking auth: $e');
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

        if (isStudent) {
          userJson['role'] = 'student';
          userJson['userType'] = 'student';
          userJson['username'] ??= userJson['student_id']?.toString();
        } else {
          userJson['role'] ??= 'doctor';
          userJson['userType'] ??= userJson['role'];
        }

        final user = User.fromJson(userJson);

        await SecureStorageService.saveUserData(jsonEncode(user.toJson()));

        final prefs = await SharedPreferences.getInstance();
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
        studentJson['username'] ??= studentJson['student_id']?.toString();

        final user = User.fromJson(studentJson);

        await SecureStorageService.saveUserData(jsonEncode(user.toJson()));

        final prefs = await SharedPreferences.getInstance();
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

        await SecureStorageService.saveUserData(jsonEncode(user.toJson()));

        final prefs = await SharedPreferences.getInstance();
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

    await SecureStorageService.saveUserData(jsonEncode(updated.toJson()));

    emit(AuthState.success(updated, token));
    logDebug('🔄 User permissions updated in AuthCubit');
  }

  Future<void> logout() async {
    await SecureStorageService.clearAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userTypeKey);

    ApiService.setToken(null);
    WebSocketService.instance.disconnect();
    emit(AuthState.loggedOut());
  }

  Future<void> refreshUserData() async {
    if (state.user == null || state.token == null) return;

    logDebug('🔄 Refreshing user data from server...');

    if (state.user!.isTeachingAssistant) {
      logDebug('ℹ️ Skipping refresh for teaching-assistant — keeping cached user');
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

        await SecureStorageService.saveUserData(
            jsonEncode(updatedUser.toJson()));

        emit(AuthState.success(updatedUser, token));

        logDebug('✅ User data refreshed successfully');
      }
    } catch (e) {
      logDebug('❌ Error refreshing user data: $e');
    }
  }
}
