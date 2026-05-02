// lib/models/student.dart
class Student {
  final int id;
  final String name;
  final String studentId;
  final int level;
  final String department;
  final Map<String, dynamic>? faceData;
  final String? academicYear;           // ✅ للعرض فقط - مش بيأثر على حساب GPA
  final int? creditsCarryOver;          // ✅ رصيد الساعات المرحل
  final int? creditsCarryOverForLevel;  // ✅ المستوى اللي رحل له الرصيد
  final Map<String, dynamic>? creditsCarryOverSource; // ✅ مصدر الرصيد

  Student({
    required this.id,
    required this.name,
    required this.studentId,
    required this.level,
    required this.department,
    this.faceData,
    this.academicYear,
    this.creditsCarryOver,
    this.creditsCarryOverForLevel,
    this.creditsCarryOverSource,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      studentId: json['student_id'] ?? '',
      level: json['level'] ?? 1,
      department: json['department'] ?? 'General',
      faceData: json['face_data'],
      academicYear: json['academic_year'],
      creditsCarryOver: json['credits_carry_over'],
      creditsCarryOverForLevel: json['credits_carry_over_for_level'],
      creditsCarryOverSource: json['credits_carry_over_source'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'student_id': studentId,
      'level': level,
      'department': department,
      'face_data': faceData,
      'academic_year': academicYear,
      'credits_carry_over': creditsCarryOver,
      'credits_carry_over_for_level': creditsCarryOverForLevel,
      'credits_carry_over_source': creditsCarryOverSource,
    };
  }
}