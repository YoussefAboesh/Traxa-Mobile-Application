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
    if (total >= 95) return 'A+';
    if (total >= 90) return 'A';
    if (total >= 85) return 'A-';
    if (total >= 80) return 'B+';
    if (total >= 75) return 'B';
    if (total >= 70) return 'B-';
    if (total >= 65) return 'C+';
    if (total >= 60) return 'C';
    if (total >= 55) return 'C-';
    if (total >= 53) return 'D+';
    if (total >= 51) return 'D';
    if (total >= 50) return 'D-';
    return 'F';
  }

  double get gradePoints {
    if (total >= 95) return 4.0;
    if (total >= 90) return 4.0;
    if (total >= 85) return 3.7;
    if (total >= 80) return 3.5;
    if (total >= 75) return 3.0;
    if (total >= 70) return 2.7;
    if (total >= 65) return 2.5;
    if (total >= 60) return 2.3;
    if (total >= 55) return 2.0;
    if (total >= 53) return 1.7;
    if (total >= 51) return 1.3;
    if (total >= 50) return 1.0;
    return 0.0;
  }

  bool get isPassed => total >= 50;

  Color get gradeColor {
    final letter = letterGrade;
    if (letter.startsWith('A')) return const Color(0xFF34D399); // Green
    if (letter.startsWith('B')) return const Color(0xFF60A5FA); // Blue
    if (letter.startsWith('C')) return const Color(0xFFFBBF24); // Yellow
    if (letter.startsWith('D')) return const Color(0xFFF97316); // Orange
    return const Color(0xFFF87171); // Red (F)
  }
}
