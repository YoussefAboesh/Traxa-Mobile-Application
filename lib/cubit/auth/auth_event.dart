import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String username;
  final String password;
  final bool isStudent;
  
  const LoginEvent({
    required this.username,
    required this.password,
    required this.isStudent,
  });
  
  @override
  List<Object?> get props => [username, password, isStudent];
}

class StudentLoginEvent extends AuthEvent {
  final String studentId;
  final String password;
  final bool isFirstLogin;
  
  const StudentLoginEvent({
    required this.studentId,
    required this.password,
    this.isFirstLogin = false,
  });
  
  @override
  List<Object?> get props => [studentId, password, isFirstLogin];
}

class DoctorLoginEvent extends AuthEvent {
  final String username;
  final String password;
  
  const DoctorLoginEvent({
    required this.username,
    required this.password,
  });
  
  @override
  List<Object?> get props => [username, password];
}

class CheckAuthEvent extends AuthEvent {}

class LogoutEvent extends AuthEvent {}