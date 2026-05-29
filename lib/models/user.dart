import 'package:collection/collection.dart';

/// Covers students, doctors, TAs and admins via role flags so screens
/// don't need to branch on separate types.
class User {
  final int id;
  final String username;
  final String name;
  final String? email;
  final String role;
  final String? userType;
  final int? supervisorDoctorId;
  final String? supervisorDoctorName;
  final int? taId;
  final Map<String, dynamic>? permissions;
  final Map<String, dynamic>? taPermissions;
  final String? department;
  final int? level;

  const User({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    required this.role,
    this.userType,
    this.supervisorDoctorId,
    this.supervisorDoctorName,
    this.taId,
    this.permissions,
    this.taPermissions,
    this.department,
    this.level,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      name: json['name'] ?? json['username'] ?? '',
      email: json['email'],
      role: json['role'] ?? (json['userType'] ?? 'student'),
      userType: json['userType'],
      supervisorDoctorId: json['supervisorDoctorId'],
      supervisorDoctorName: json['supervisorDoctorName'],
      taId: json['taId'],
      permissions: json['permissions'] != null
          ? Map<String, dynamic>.from(json['permissions'])
          : null,
      taPermissions: json['taPermissions'] != null
          ? Map<String, dynamic>.from(json['taPermissions'])
          : null,
      department: json['department'],
      level: json['level'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'email': email,
        'role': role,
        'userType': userType,
        'supervisorDoctorId': supervisorDoctorId,
        'supervisorDoctorName': supervisorDoctorName,
        'taId': taId,
        'permissions': permissions,
        'taPermissions': taPermissions,
        'department': department,
        'level': level,
      };

  User copyWith({
    int? id,
    String? username,
    String? name,
    String? email,
    String? role,
    String? userType,
    int? supervisorDoctorId,
    String? supervisorDoctorName,
    int? taId,
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? taPermissions,
    String? department,
    int? level,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      userType: userType ?? this.userType,
      supervisorDoctorId: supervisorDoctorId ?? this.supervisorDoctorId,
      supervisorDoctorName: supervisorDoctorName ?? this.supervisorDoctorName,
      taId: taId ?? this.taId,
      permissions: permissions ?? this.permissions,
      taPermissions: taPermissions ?? this.taPermissions,
      department: department ?? this.department,
      level: level ?? this.level,
    );
  }

  bool get isDoctor => role == 'doctor' || userType == 'doctor';
  bool get isStudent => role == 'student' || userType == 'student';
  bool get isTeachingAssistant =>
      userType == 'teaching-assistant' || role == 'teaching-assistant';

  int get effectiveDoctorId =>
      isTeachingAssistant ? (supervisorDoctorId ?? id) : id;

  bool hasTAPermission(String key) {
    if (!isTeachingAssistant) return true;
    return permissions?[key] == true;
  }

  bool canActivateSessionForSubject(int subjectId) {
    if (!isTeachingAssistant) return true;
    final p = taPermissions?['$subjectId'];
    if (p is Map && p['ta.session.activate'] == false) return false;
    return true;
  }

  static const _mapEq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          name == other.name &&
          email == other.email &&
          role == other.role &&
          userType == other.userType &&
          supervisorDoctorId == other.supervisorDoctorId &&
          supervisorDoctorName == other.supervisorDoctorName &&
          taId == other.taId &&
          _mapEq.equals(permissions, other.permissions) &&
          _mapEq.equals(taPermissions, other.taPermissions) &&
          department == other.department &&
          level == other.level;

  @override
  int get hashCode => Object.hash(
        id,
        username,
        name,
        email,
        role,
        userType,
        supervisorDoctorId,
        supervisorDoctorName,
        taId,
        _mapEq.hash(permissions),
        _mapEq.hash(taPermissions),
        department,
        level,
      );

  @override
  String toString() =>
      'User(id: $id, username: $username, name: $name, role: $role)';
}
