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

  const Grade({
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

  Grade copyWith({
    int? id,
    int? studentId,
    String? studentName,
    int? subjectId,
    String? subjectName,
    int? doctorId,
    int? level,
    String? department,
    double? midterm,
    double? oral,
    double? practical,
    double? attendance,
    double? assignment,
    double? finalExam,
    double? total,
    int? semester,
    String? academicYear,
    bool? isVisible,
  }) {
    return Grade(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      doctorId: doctorId ?? this.doctorId,
      level: level ?? this.level,
      department: department ?? this.department,
      midterm: midterm ?? this.midterm,
      oral: oral ?? this.oral,
      practical: practical ?? this.practical,
      attendance: attendance ?? this.attendance,
      assignment: assignment ?? this.assignment,
      finalExam: finalExam ?? this.finalExam,
      total: total ?? this.total,
      semester: semester ?? this.semester,
      academicYear: academicYear ?? this.academicYear,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Grade &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          studentId == other.studentId &&
          studentName == other.studentName &&
          subjectId == other.subjectId &&
          subjectName == other.subjectName &&
          doctorId == other.doctorId &&
          level == other.level &&
          department == other.department &&
          midterm == other.midterm &&
          oral == other.oral &&
          practical == other.practical &&
          attendance == other.attendance &&
          assignment == other.assignment &&
          finalExam == other.finalExam &&
          total == other.total &&
          semester == other.semester &&
          academicYear == other.academicYear &&
          isVisible == other.isVisible;

  @override
  int get hashCode => Object.hashAll([
        id,
        studentId,
        studentName,
        subjectId,
        subjectName,
        doctorId,
        level,
        department,
        midterm,
        oral,
        practical,
        attendance,
        assignment,
        finalExam,
        total,
        semester,
        academicYear,
        isVisible,
      ]);

  @override
  String toString() =>
      'Grade(studentId: $studentId, subject: $subjectName, total: $total, visible: $isVisible)';

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

  String get gradeLetter {
    final pct = total;
    if (pct >= 96) return 'A+';
    if (pct >= 92) return 'A';
    if (pct >= 88) return 'A-';
    if (pct >= 84) return 'B+';
    if (pct >= 80) return 'B';
    if (pct >= 76) return 'B-';
    if (pct >= 72) return 'C+';
    if (pct >= 68) return 'C';
    if (pct >= 64) return 'C-';
    if (pct >= 60) return 'D+';
    if (pct >= 55) return 'D';
    if (pct >= 50) return 'D-';
    return 'F';
  }

  double get gradePoints {
    final pct = total;
    if (pct >= 96) return 4.0;
    if (pct >= 92) return 3.7;
    if (pct >= 88) return 3.4;
    if (pct >= 84) return 3.2;
    if (pct >= 80) return 3.0;
    if (pct >= 76) return 2.8;
    if (pct >= 72) return 2.6;
    if (pct >= 68) return 2.4;
    if (pct >= 64) return 2.2;
    if (pct >= 60) return 2.0;
    if (pct >= 55) return 1.5;
    if (pct >= 50) return 1.0;
    return 0.0;
  }

  bool get isPassed => total >= 50;

  Color get gradeColor {
    final pct = total;
    if (pct >= 92) return const Color(0xFF10B981);
    if (pct >= 84) return const Color(0xFF34D399);
    if (pct >= 76) return const Color(0xFFFBBF24);
    if (pct >= 68) return const Color(0xFFF59E0B);
    if (pct >= 60) return const Color(0xFFF97316);
    if (pct >= 50) return const Color(0xFFF87171);
    return const Color(0xFFEF4444);
  }
}
