// lib/cubit/data/data_state.dart
import 'package:equatable/equatable.dart';
import '../../models/student.dart';
import '../../models/doctor.dart';
import '../../models/subject.dart';
import '../../models/lecture.dart';
import '../../models/grade.dart';
import '../../models/attendance.dart';
import '../shared/loading_state.dart';

class DataState extends Equatable {
  final List<Student> students;
  final List<Doctor> doctors;
  final List<Subject> subjects;
  final List<Lecture> lectures;
  final List<Subject> allSubjects;
  final List<Lecture> allLectures;
  final List<Grade> grades;
  final List<Grade> allGrades;
  final List<AttendanceRecord> attendance;
  final LoadingState loadingState;
  final int currentSemester;

  const DataState({
    this.students = const [],
    this.doctors = const [],
    this.subjects = const [],
    this.lectures = const [],
    this.allSubjects = const [],
    this.allLectures = const [],
    this.grades = const [],
    this.allGrades = const [],
    this.attendance = const [],
    this.loadingState = const LoadingState(),
    this.currentSemester = 1,
  });

  DataState copyWith({
    List<Student>? students,
    List<Doctor>? doctors,
    List<Subject>? subjects,
    List<Lecture>? lectures,
    List<Subject>? allSubjects,
    List<Lecture>? allLectures,
    List<Grade>? grades,
    List<Grade>? allGrades,
    List<AttendanceRecord>? attendance,
    LoadingState? loadingState,
    int? currentSemester,
  }) {
    return DataState(
      students: students ?? this.students,
      doctors: doctors ?? this.doctors,
      subjects: subjects ?? this.subjects,
      lectures: lectures ?? this.lectures,
      allSubjects: allSubjects ?? this.allSubjects,
      allLectures: allLectures ?? this.allLectures,
      grades: grades ?? this.grades,
      allGrades: allGrades ?? this.allGrades,
      attendance: attendance ?? this.attendance,
      loadingState: loadingState ?? this.loadingState,
      currentSemester: currentSemester ?? this.currentSemester,
    );
  }

  @override
  List<Object?> get props => [
        students,
        doctors,
        subjects,
        lectures,
        allSubjects,
        allLectures,
        grades,
        allGrades,
        attendance,
        loadingState,
        currentSemester
      ];

  // Helper methods
  List<Subject> getSubjectsForDoctor(int doctorId) {
    return subjects.where((s) => s.doctorId == doctorId).toList();
  }

  List<Lecture> getLecturesForDoctor(int doctorId) {
    return lectures.where((l) => l.doctorId == doctorId).toList();
  }

  List<Subject> getSubjectsForStudent(Student student) {
    return subjects
        .where((s) =>
            s.level == student.level && s.department == student.department)
        .toList();
  }

  List<Lecture> getLecturesForStudent(Student student) {
    return lectures
        .where((l) =>
            l.level == student.level && l.department == student.department)
        .toList();
  }

  // ✅ Get grades for a specific semester (student can choose)
  List<Grade> getGradesForStudentAndSemester(int studentId, int semester) {
    return allGrades
        .where((g) =>
            g.studentId == studentId && g.semester == semester && g.isVisible)
        .toList();
  }

  // ✅ Get all grades for student (all semesters)
  List<Grade> getAllGradesForStudent(int studentId) {
    return allGrades
        .where((g) => g.studentId == studentId && g.isVisible)
        .toList();
  }

  String get semesterDisplay =>
      currentSemester == 1 ? 'First Semester' : 'Second Semester';

  factory DataState.initial() => const DataState();
  factory DataState.loading() =>
      DataState(loadingState: LoadingState.loading());
  factory DataState.loaded({
    required List<Student> students,
    required List<Doctor> doctors,
    required List<Subject> subjects,
    required List<Lecture> lectures,
    List<Subject>? allSubjects,
    List<Lecture>? allLectures,
    int? currentSemester,
  }) =>
      DataState(
        students: students,
        doctors: doctors,
        subjects: subjects,
        lectures: lectures,
        allSubjects: allSubjects ?? subjects,
        allLectures: allLectures ?? lectures,
        currentSemester: currentSemester ?? 1,
        loadingState: LoadingState.loaded(),
      );
  factory DataState.error(String message) => DataState(
        loadingState: LoadingState.error(message),
      );
}
