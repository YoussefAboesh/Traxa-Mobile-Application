import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/service_locator.dart';
import '../../core/logger.dart';
import '../../repositories/auth_repository.dart';
import '../../services/secure_storage_service.dart';
import '../../services/websocket_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({AuthRepository? repository})
      : _repo = repository ?? getIt<AuthRepository>(),
        super(AuthState.initial());

  final AuthRepository _repo;

  /// Bootstrap entry point. Called explicitly by the service locator
  /// instead of from the constructor, so construction stays side-effect
  /// free and tests don't accidentally touch storage.
  Future<void> init() => checkAuth();

  Future<void> checkAuth() async {
    final result = await _repo.restoreSession();
    result.when(
      success: (session) async {
        if (session == null) {
          emit(AuthState.initial());
          return;
        }
        emit(AuthState.success(session.user, session.token));
        await WebSocketService.instance.connect();
        AppLogger.i('Session restored', tag: 'AuthCubit');
      },
      failure: (e) {
        AppLogger.e('Failed to restore session', tag: 'AuthCubit', error: e);
        emit(AuthState.error('Failed to restore session'));
      },
    );
  }

  Future<void> login({
    required String username,
    required String password,
    required bool isStudent,
  }) async {
    emit(AuthState.loading());

    final result = isStudent
        ? await _repo.studentLogin(studentId: username, password: password)
        : await _repo.doctorLogin(username: username, password: password);

    await result.when(
      success: (session) async {
        emit(AuthState.success(session.user, session.token));
        await WebSocketService.instance.connect();
      },
      failure: (e) async => emit(AuthState.error(e.message)),
    );
  }

  Future<void> studentLogin({
    required String studentId,
    required String password,
    bool isFirstLogin = false,
  }) async {
    emit(AuthState.loading());
    final result = await _repo.studentLogin(
      studentId: studentId,
      password: password,
      isFirstLogin: isFirstLogin,
    );
    await result.when(
      success: (s) async {
        emit(AuthState.success(s.user, s.token));
        await WebSocketService.instance.connect();
      },
      failure: (e) async => emit(AuthState.error(e.message)),
    );
  }

  Future<void> doctorLogin({
    required String username,
    required String password,
  }) async {
    emit(AuthState.loading());
    final result = await _repo.doctorLogin(username: username, password: password);
    await result.when(
      success: (s) async {
        emit(AuthState.success(s.user, s.token));
        await WebSocketService.instance.connect();
      },
      failure: (e) async => emit(AuthState.error(e.message)),
    );
  }

  Future<void> updateUserPermissions(Map<String, dynamic> newPerms) async {
    final user = state.user;
    final token = state.token;
    if (user == null || token == null) return;

    final updated = user.copyWith(permissions: Map<String, dynamic>.from(newPerms));
    await SecureStorageService.saveUserData(jsonEncode(updated.toJson()));
    emit(AuthState.success(updated, token));
    AppLogger.i('User permissions updated', tag: 'AuthCubit');
  }

  Future<void> logout() async {
    await _repo.logout();
    WebSocketService.instance.disconnect();
    emit(AuthState.loggedOut());
  }

  Future<void> refreshUserData() async {
    final user = state.user;
    final token = state.token;
    if (user == null || token == null) return;

    final result = await _repo.refreshUser(current: user, token: token);
    result.when(
      success: (fresh) {
        if (fresh == null) return;
        emit(AuthState.success(fresh, token));
      },
      failure: (e) =>
          AppLogger.w('Refresh failed', tag: 'AuthCubit', error: e),
    );
  }
}
