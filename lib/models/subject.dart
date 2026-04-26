// lib/models/subject.dart
class Subject {
  final int id;
  final String? code;
  final String name;
  final int doctorId;
  final String doctorName;
  final int level;
  final int semester;
  final String? department;
  final int? credits;
  final int? creditHours;

  Subject({
    required this.id,
    this.code,
    required this.name,
    required this.doctorId,
    required this.doctorName,
    required this.level,
    required this.semester,
    this.department,
    this.credits,
    this.creditHours,
  });

  // دالة مساعدة للحصول على عدد الساعات (تجمع بين الحقلين)
  int get totalCreditHours {
    if (credits != null && credits! > 0) return credits!;
    if (creditHours != null && creditHours! > 0) return creditHours!;
    return 3; // القيمة الافتراضية
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? 0,
      code: json['code'],
      name: json['name'] ?? '',
      doctorId: json['doctor_id'] ?? 0,
      doctorName: json['doctor_name'] ?? 'Not Assigned',
      level: json['level'] ?? 1,
      semester: json['semester'] ?? 1,
      department: json['department'],
      credits: json['credits'],
      creditHours: json['credit_hours'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'level': level,
      'semester': semester,
      'department': department,
      'credits': credits,
      'credit_hours': creditHours,
    };
  }
}