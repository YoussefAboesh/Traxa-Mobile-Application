import 'package:collection/collection.dart';

class TeachingAssistant {
  final int id;
  final String name;
  final String username;
  final String? email;
  final int? supervisorDoctorId;
  final Map<String, dynamic>? permissions;
  final List<int> assignedSubjectIds;

  const TeachingAssistant({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.supervisorDoctorId,
    this.permissions,
    this.assignedSubjectIds = const [],
  });

  factory TeachingAssistant.fromJson(Map<String, dynamic> json) {
    return TeachingAssistant(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['username'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      supervisorDoctorId:
          json['supervisor_doctor_id'] ?? json['supervisorDoctorId'],
      permissions: json['permissions'] != null
          ? Map<String, dynamic>.from(json['permissions'])
          : null,
      assignedSubjectIds: json['assigned_subject_ids'] != null
          ? List<int>.from(json['assigned_subject_ids'])
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'supervisor_doctor_id': supervisorDoctorId,
        'permissions': permissions,
        'assigned_subject_ids': assignedSubjectIds,
      };

  TeachingAssistant copyWith({
    int? id,
    String? name,
    String? username,
    String? email,
    int? supervisorDoctorId,
    Map<String, dynamic>? permissions,
    List<int>? assignedSubjectIds,
  }) {
    return TeachingAssistant(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      supervisorDoctorId: supervisorDoctorId ?? this.supervisorDoctorId,
      permissions: permissions ?? this.permissions,
      assignedSubjectIds: assignedSubjectIds ?? this.assignedSubjectIds,
    );
  }

  bool get hasPermissions => permissions != null && permissions!.isNotEmpty;

  bool hasPermission(String key) {
    if (permissions == null) return false;
    return permissions![key] == true;
  }

  bool get isAssignedToSubject => assignedSubjectIds.isNotEmpty;

  static const _deepEq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeachingAssistant &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          username == other.username &&
          email == other.email &&
          supervisorDoctorId == other.supervisorDoctorId &&
          _deepEq.equals(permissions, other.permissions) &&
          _deepEq.equals(assignedSubjectIds, other.assignedSubjectIds);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        username,
        email,
        supervisorDoctorId,
        _deepEq.hash(permissions),
        _deepEq.hash(assignedSubjectIds),
      );

  @override
  String toString() => 'TA(id: $id, username: $username, name: $name)';
}
