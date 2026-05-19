import '../models/student.dart';
import '../models/doctor.dart';
import '../models/grade.dart';
import '../models/subject.dart';

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
    return null;
  }
}

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

Subject? findSubjectSafely(int subjectId, List<Subject> subjects) {
  if (subjects.isEmpty) return null;
  try {
    return subjects.firstWhere((s) => s.id == subjectId);
  } catch (_) {
    return null;
  }
}

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

  final gpa = totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  return double.parse(gpa.toStringAsFixed(2));
}

double calculateSemesterGPA(
    List<Grade> grades, List<Subject> subjects, int semester) {
  final semesterGrades =
      grades.where((g) => g.semester == semester && g.isVisible).toList();
  return calculateGPA(semesterGrades, subjects);
}

double calculateLevelGPA(
    List<Grade> grades, List<Subject> subjects, int level) {
  final levelGrades =
      grades.where((g) => g.level == level && g.isVisible).toList();
  return calculateGPA(levelGrades, subjects);
}

double calculateCumulativeGPA(List<Grade> grades, List<Subject> subjects) {
  return calculateGPA(grades, subjects);
}

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

int countPassedSubjects(List<Grade> grades) {
  return grades.where((g) => g.total >= 50 && g.isVisible).length;
}

int countFailedSubjects(List<Grade> grades) {
  return grades.where((g) => g.total < 50 && g.total > 0 && g.isVisible).length;
}

double roundToTwoDecimals(double value) {
  return double.parse(value.toStringAsFixed(2));
}

String getGradeLabel(double gpa) {
  if (gpa >= 3.7) return 'Excellent';
  if (gpa >= 3.3) return 'Very Good';
  if (gpa >= 2.7) return 'Good';
  if (gpa >= 2.0) return 'Satisfactory';
  if (gpa >= 1.7) return 'Pass';
  return 'Needs Improvement';
}
