// lib/models/user.dart
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
  // صلاحيات المعيد لكل مادة — المفتاح = subjectId كنص، القيمة { 'ta.session.activate': bool, 'ta.grades.manage': bool }
  final Map<String, dynamic>? taPermissions;
  final String? department;   // ✅ أضف هذا
  final int? level;           // ✅ أضف هذا

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
    this.taPermissions,
    this.department,    // ✅
    this.level,         // ✅
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
      taPermissions: json['taPermissions'] != null
          ? Map<String, dynamic>.from(json['taPermissions'])
          : null,
      department: json['department'],   // ✅
      level: json['level'],             // ✅
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
      'taPermissions': taPermissions,
      'department': department,   // ✅
      'level': level,             // ✅
    };
  }

  bool get isDoctor => role == 'doctor' || userType == 'doctor';
  bool get isStudent => role == 'student' || userType == 'student';
  bool get isTeachingAssistant =>
      userType == 'teaching-assistant' || role == 'teaching-assistant';

  int get effectiveDoctorId =>
      isTeachingAssistant ? (supervisorDoctorId ?? id) : id;

  bool hasTAPermission(String key) {
    if (!isTeachingAssistant) return true;
    final v = permissions?[key];
    return v == true;
  }

  /// هل المعيد مسموح له يفعّل/ينهي سيشن للمادة دي؟
  /// الافتراضي مسموح (زي السيرفر) — بيتقفل بس لو الدكتور قفله صراحةً.
  bool canActivateSessionForSubject(int subjectId) {
    if (!isTeachingAssistant) return true;
    final p = taPermissions?['$subjectId'];
    if (p is Map && p['ta.session.activate'] == false) return false;
    return true;
  }
}