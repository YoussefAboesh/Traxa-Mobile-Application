// lib/core/helpers.dart
// ✅ دوال مشتركة — بدل تكرارها في كل شاشة

import '../models/student.dart';
import '../models/doctor.dart';
import '../models/grade.dart';
import '../models/subject.dart';

/// البحث عن الطالب بأمان — بدل orElse: () => students.first اللي بترجع طالب غلط
Student? findStudentSafely({
  required int userId,
  required String username,
  required List<Student> students,
}) {
  if (students.isEmpty) return null;
  try {
    return students.firstWhere(
      (s) => s.id == userId || s.studentId == username,
    );
  } catch (_) {
    return null; // ✅ بدل ما يرجع أول طالب في الليست
  }
}

/// البحث عن الدكتور بأمان
Doctor? findDoctorSafely({
  required int userId,
  required String username,
  required List<Doctor> doctors,
}) {
  if (doctors.isEmpty) return null;
  try {
    return doctors.firstWhere(
      (d) => d.id == userId || d.username == username,
    );
  } catch (_) {
    return null;
  }
}

/// البحث عن مادة بأمان (للدرجات)
Subject? findSubjectSafely(int subjectId, List<Subject> subjects) {
  if (subjects.isEmpty) return null;
  try {
    return subjects.firstWhere((s) => s.id == subjectId);
  } catch (_) {
    return null;
  }
}

/// اسم اليوم الحالي — الـ fix الصحيح
/// DateTime.weekday: Monday=1, Sunday=7
/// الأيام عندنا: Saturday, Sunday, Monday, ...
String getTodayDayName() {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return days[DateTime.now().weekday - 1];
}

/// حساب GPA موحد — بدل ما يتكرر في 3 أماكن
double calculateGPA(List<Grade> grades, List<Subject> subjects) {
  if (grades.isEmpty || subjects.isEmpty) return 0.0;

  double totalPoints = 0;
  int totalCredits = 0;

  for (final grade in grades) {
    if (!grade.isVisible) continue;

    final subject = findSubjectSafely(grade.subjectId, subjects);
    if (subject == null) continue; // ✅ بدل orElse: () => subjects.first

    final credits = subject.totalCreditHours;
    totalPoints += grade.gradePoints * credits;
    totalCredits += credits;
  }

  return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
}

/// حساب الساعات المكتسبة (passed فقط)
int calculateEarnedCredits(List<Grade> grades, List<Subject> subjects) {
  int total = 0;
  for (final grade in grades) {
    if (grade.total >= 50 && grade.isVisible) {
      final subject = findSubjectSafely(grade.subjectId, subjects);
      if (subject != null) {
        total += subject.totalCreditHours;
      }
    }
  }
  return total;
}
