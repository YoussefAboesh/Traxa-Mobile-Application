import 'package:collection/collection.dart';

class Student {
  final int id;
  final String name;
  final String studentId;
  final int level;
  final String department;
  final Map<String, dynamic>? faceData;
  final String? academicYear;

  const Student({
    required this.id,
    required this.name,
    required this.studentId,
    required this.level,
    required this.department,
    this.faceData,
    this.academicYear,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      studentId: json['student_id'] ?? '',
      level: json['level'] ?? 1,
      department: json['department'] ?? 'General',
      faceData: json['face_data'] != null
          ? Map<String, dynamic>.from(json['face_data'])
          : null,
      academicYear: json['academic_year'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'student_id': studentId,
        'level': level,
        'department': department,
        'face_data': faceData,
        'academic_year': academicYear,
      };

  Student copyWith({
    int? id,
    String? name,
    String? studentId,
    int? level,
    String? department,
    Map<String, dynamic>? faceData,
    String? academicYear,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      level: level ?? this.level,
      department: department ?? this.department,
      faceData: faceData ?? this.faceData,
      academicYear: academicYear ?? this.academicYear,
    );
  }

  static const _mapEq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          studentId == other.studentId &&
          level == other.level &&
          department == other.department &&
          _mapEq.equals(faceData, other.faceData) &&
          academicYear == other.academicYear;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        studentId,
        level,
        department,
        _mapEq.hash(faceData),
        academicYear,
      );

  @override
  String toString() =>
      'Student(id: $id, studentId: $studentId, name: $name, level: $level)';
}
