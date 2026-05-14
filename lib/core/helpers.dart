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
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  return days[DateTime.now().weekday - 1];
}

/// ✅ حساب GPA حسب الجدول الرسمي لكلية الحاسبات والمعلومات
/// المعادلة: GPA = مجموع (نقاط المادة × ساعاتها) / مجموع الساعات
/// التقريب لأقرب رقمين عشريين
double calculateGPA(List<Grade> grades, List<Subject> subjects) {
  if (grades.isEmpty || subjects.isEmpty) return 0.0;

  double totalPoints = 0;
  int totalCredits = 0;

  for (final grade in grades) {
    if (!grade.isVisible) continue;

    final subject = findSubjectSafely(grade.subjectId, subjects);
    if (subject == null) continue;

    final credits = subject.totalCreditHours;
    totalPoints += grade.gradePoints * credits;
    totalCredits += credits;
  }

  // التقريب لأقرب رقمين عشريين
  final gpa = totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  return double.parse(gpa.toStringAsFixed(2));
}

/// ✅ حساب GPA الفصلي (Semester GPA)
double calculateSemesterGPA(
    List<Grade> grades, List<Subject> subjects, int semester) {
  final semesterGrades =
      grades.where((g) => g.semester == semester && g.isVisible).toList();
  return calculateGPA(semesterGrades, subjects);
}

/// ✅ حساب GPA لمستوى معين
double calculateLevelGPA(
    List<Grade> grades, List<Subject> subjects, int level) {
  final levelGrades =
      grades.where((g) => g.level == level && g.isVisible).toList();
  return calculateGPA(levelGrades, subjects);
}

/// ✅ حساب المعدل التراكمي المجمع (CGPA) - نفس صيغة الـ GPA
double calculateCumulativeGPA(List<Grade> grades, List<Subject> subjects) {
  return calculateGPA(grades, subjects);
}

/// ✅ حساب الساعات المكتسبة (النجاح بـ 50% فأكثر - D- فأعلى)
int calculateEarnedCredits(List<Grade> grades, List<Subject> subjects) {
  int total = 0;
  for (final grade in grades) {
    if (grade.total >= 50 && grade.isVisible) {
      // النجاح من 50% (D-)
      final subject = findSubjectSafely(grade.subjectId, subjects);
      if (subject != null) {
        total += subject.totalCreditHours;
      }
    }
  }
  return total;
}

/// ✅ حساب الساعات المسجلة (كل المواد المسجلة)
int calculateRegisteredCredits(List<Grade> grades, List<Subject> subjects) {
  int total = 0;
  for (final grade in grades) {
    if (grade.isVisible) {
      final subject = findSubjectSafely(grade.subjectId, subjects);
      if (subject != null) {
        total += subject.totalCreditHours;
      }
    }
  }
  return total;
}

/// ✅ حساب مجموع النقاط × الساعات (للتأكيد)
double calculateTotalGradePoints(List<Grade> grades, List<Subject> subjects) {
  double total = 0;
  for (final grade in grades) {
    if (grade.isVisible) {
      final subject = findSubjectSafely(grade.subjectId, subjects);
      if (subject != null) {
        total += grade.gradePoints * subject.totalCreditHours;
      }
    }
  }
  return double.parse(total.toStringAsFixed(2));
}

/// ✅ حساب عدد المواد الناجحة
int countPassedSubjects(List<Grade> grades) {
  return grades.where((g) => g.total >= 50 && g.isVisible).length;
}

/// ✅ حساب عدد المواد الراسبة
int countFailedSubjects(List<Grade> grades) {
  return grades.where((g) => g.total < 50 && g.total > 0 && g.isVisible).length;
}

/// ✅ التقريب لأقرب رقمين عشريين
double roundToTwoDecimals(double value) {
  return double.parse(value.toStringAsFixed(2));
}

/// ✅ الحصول على تقييم الدرجات بناءً على المعدل
String getGradeLabel(double gpa) {
  if (gpa >= 3.7) return 'Excellent';
  if (gpa >= 3.3) return 'Very Good';
  if (gpa >= 2.7) return 'Good';
  if (gpa >= 2.0) return 'Satisfactory';
  if (gpa >= 1.7) return 'Pass';
  return 'Needs Improvement';
}
