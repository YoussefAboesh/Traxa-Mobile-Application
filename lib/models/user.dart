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

  User({
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
      permissions: json['permissions'] != null ? Map<String, dynamic>.from(json['permissions']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  bool get isDoctor => role == 'doctor' || userType == 'doctor';
  bool get isStudent => role == 'student' || userType == 'student';
  bool get isTeachingAssistant =>
      userType == 'teaching-assistant' || role == 'teaching-assistant';

  /// The doctor id whose data this user should see.
  /// For a doctor → their own id. For a TA → their supervising doctor's id.
  int get effectiveDoctorId =>
      isTeachingAssistant ? (supervisorDoctorId ?? id) : id;

  /// True if a TA permission key is granted. Doctors always return true.
  bool hasTAPermission(String key) {
    if (!isTeachingAssistant) return true;
    final v = permissions?[key];
    return v == true;
  }
}