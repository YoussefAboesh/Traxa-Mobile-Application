import 'package:flutter/material.dart';

class Grade {
  final int id;
  final int studentId;
  final String studentName;
  final int subjectId;
  final String subjectName;
  final int doctorId;
  final int level;
  final String department;
  final double midterm;
  final double oral;
  final double practical;
  final double attendance;
  final double assignment;
  final double finalExam;
  final double total;
  final int semester;
  final String academicYear;
  final bool isVisible;

  Grade({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    required this.doctorId,
    required this.level,
    required this.department,
    required this.midterm,
    required this.oral,
    required this.practical,
    required this.attendance,
    required this.assignment,
    required this.finalExam,
    required this.total,
    required this.semester,
    required this.academicYear,
    required this.isVisible,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      subjectId: json['subject_id'] ?? 0,
      subjectName: json['subject_name'] ?? '',
      doctorId: json['doctor_id'] ?? 0,
      level: json['level'] ?? 1,
      department: json['department'] ?? '',
      midterm: (json['midterm'] ?? 0).toDouble(),
      oral: (json['oral'] ?? 0).toDouble(),
      practical: (json['practical'] ?? 0).toDouble(),
      attendance: (json['attendance'] ?? 0).toDouble(),
      assignment: (json['assignment'] ?? 0).toDouble(),
      finalExam: (json['final_exam'] ?? json['final'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      semester: json['semester'] ?? 1,
      academicYear: json['academic_year'] ?? '',
      isVisible: json['isVisible'] ?? false,
    );
  }

  String get letterGrade {
    if (total >= 45) return 'A';
    if (total >= 40) return 'B';
    if (total >= 35) return 'C';
    if (total >= 30) return 'D';
    if (total >= 25) return 'E';
    return 'F';
  }

  bool get isPassed => total >= 25;
  Color get gradeColor {
    if (total >= 45) return const Color(0xFF34D399);
    if (total >= 35) return const Color(0xFF60A5FA);
    if (total >= 25) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }
}
