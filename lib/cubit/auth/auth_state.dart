import 'package:equatable/equatable.dart';
import '../../models/user.dart';
import '../shared/loading_state.dart';

class AuthState extends Equatable {
  final User? user;
  final String? token;
  final bool isAuthenticated;
  final LoadingState loadingState;
  
  const AuthState({
    this.user,
    this.token,
    this.isAuthenticated = false,
    this.loadingState = const LoadingState(),
  });
  
  AuthState copyWith({
    User? user,
    String? token,
    bool? isAuthenticated,
    LoadingState? loadingState,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      loadingState: loadingState ?? this.loadingState,
    );
  }
  
  @override
  List<Object?> get props => [user, token, isAuthenticated, loadingState];
  
  factory AuthState.initial() => const AuthState();
  factory AuthState.loading() => AuthState(
    loadingState: LoadingState.loading(),
  );
  factory AuthState.success(User user, String token) => AuthState(
    user: user,
    token: token,
    isAuthenticated: true,
    loadingState: LoadingState.loaded(),
  );
  factory AuthState.error(String message) => AuthState(
    loadingState: LoadingState.error(message),
  );
  factory AuthState.loggedOut() => const AuthState();
}