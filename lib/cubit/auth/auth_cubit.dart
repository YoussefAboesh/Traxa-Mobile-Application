import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
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
        final Map<String, dynamic> userJson = Map<String, dynamic>.from(
          response[isStudent ? 'student' : 'user']
        );
        
        // التأكد من وجود الحقول المطلوبة للموديل
        userJson['role'] = isStudent ? 'student' : 'doctor';
        userJson['userType'] = isStudent ? 'student' : 'doctor';
        
        final user = User.fromJson(userJson);
        
        ApiService.setToken(token);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token as String);
        await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString(AppConstants.userTypeKey, user.userType ?? (isStudent ? 'student' : 'doctor'));
        
        emit(AuthState.success(user, token));
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
      final response = await ApiService.studentLogin(studentId, password, isFirstLogin);
      
      if (response['success'] == true) {
        final token = response['token'];
        final Map<String, dynamic> studentJson = Map<String, dynamic>.from(response['student']);
        
        studentJson['role'] = 'student';
        studentJson['userType'] = 'student';
        
        final user = User.fromJson(studentJson);
        
        ApiService.setToken(token);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token as String);
        await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString(AppConstants.userTypeKey, 'student');
        
        emit(AuthState.success(user, token));
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
        final Map<String, dynamic> userJson = Map<String, dynamic>.from(response['user']);
        
        final user = User.fromJson(userJson);
        
        ApiService.setToken(token);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token as String);
        await prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));
        await prefs.setString(AppConstants.userTypeKey, 'doctor');
        
        emit(AuthState.success(user, token));
      } else {
        emit(AuthState.error(response['error'] ?? 'Login failed'));
      }
    } catch (e) {
      emit(AuthState.error('Connection error: ${e.toString()}'));
    }
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userDataKey);
    await prefs.remove(AppConstants.userTypeKey);
    
    ApiService.setToken(null);
    emit(AuthState.loggedOut());
  }
}
