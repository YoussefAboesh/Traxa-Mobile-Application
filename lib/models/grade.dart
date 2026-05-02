// lib/models/grade.dart
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
      finalExam: (json['final'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      semester: json['semester'] ?? 1,
      academicYear: json['academic_year'] ?? '',
      isVisible: json['isVisible'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'doctor_id': doctorId,
      'level': level,
      'department': department,
      'midterm': midterm,
      'oral': oral,
      'practical': practical,
      'attendance': attendance,
      'assignment': assignment,
      'final': finalExam,
      'total': total,
      'semester': semester,
      'academic_year': academicYear,
      'isVisible': isVisible,
    };
  }

  // ✅ تحويل النسبة المئوية إلى Grade Letter (حسب جدول التقديرات المطلوب)
  String get gradeLetter {
    final pct = total;
    if (pct >= 95) return 'A+';
    if (pct >= 90) return 'A';
    if (pct >= 85) return 'A-';
    if (pct >= 80) return 'B+';
    if (pct >= 75) return 'B';
    if (pct >= 71) return 'B-';
    if (pct >= 70) return 'C+';
    if (pct >= 65) return 'C';
    if (pct >= 60) return 'C-';
    if (pct >= 55) return 'D+';
    if (pct >= 53) return 'D';
    if (pct >= 50) return 'D-';
    return 'F';
  }

  // ✅ تحويل النسبة المئوية إلى Grade Points
  double get gradePoints {
    final pct = total;
    if (pct >= 95) return 4.0;
    if (pct >= 90) return 4.0;
    if (pct >= 85) return 3.7;
    if (pct >= 80) return 3.5;
    if (pct >= 75) return 3.0;
    if (pct >= 71) return 2.7;
    if (pct >= 70) return 2.5;
    if (pct >= 65) return 2.3;
    if (pct >= 60) return 2.0;
    if (pct >= 55) return 1.7;
    if (pct >= 53) return 1.3;
    if (pct >= 50) return 1.0;
    return 0.0;
  }

  bool get isPassed => total >= 50;
  
  Color get gradeColor {
    final pct = total;
    if (pct >= 85) return const Color(0xFF34D399);
    if (pct >= 75) return const Color(0xFF10B981);
    if (pct >= 65) return const Color(0xFFFBBF24);
    if (pct >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFF87171);
  }
}