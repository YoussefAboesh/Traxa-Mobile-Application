// lib/models/teaching_assistant.dart

class TeachingAssistant {
  final int id;
  final String name;
  final String username;
  final String? email;
  final int? supervisorDoctorId;
  final Map<String, dynamic>? permissions;
  final List<int> assignedSubjectIds;

  TeachingAssistant({
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
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'supervisor_doctor_id': supervisorDoctorId,
      'permissions': permissions,
      'assigned_subject_ids': assignedSubjectIds,
    };
  }

  bool get hasPermissions => permissions != null && permissions!.isNotEmpty;
  
  bool hasPermission(String key) {
    if (permissions == null) return false;
    return permissions![key] == true;
  }
  
  bool get isAssignedToSubject => assignedSubjectIds.isNotEmpty;
}