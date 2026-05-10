class TeachingAssistant {
  final int id;
  final String name;
  final String username;
  final String? email;
  final int? supervisorDoctorId;
  final Map<String, dynamic>? permissions;

  TeachingAssistant({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.supervisorDoctorId,
    this.permissions,
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
    );
  }
}
