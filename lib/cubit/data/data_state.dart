// lib/cubit/data/data_state.dart
import 'package:equatable/equatable.dart';
import '../../models/student.dart';
import '../../models/doctor.dart';
import '../../models/subject.dart';
import '../../models/lecture.dart';
import '../../models/grade.dart';
import '../../models/attendance.dart';
import '../../models/teaching_assistant.dart';
import '../../models/section.dart';
import '../shared/loading_state.dart';

class DataState extends Equatable {
  final List<Student> students;
  final List<Doctor> doctors;
  final List<Subject> subjects;
  final List<Lecture> lectures;
  final List<Subject> allSubjects;
  final List<Lecture> allLectures;
  final List<Section> allSections; // ← جديد
  final List<Grade> grades;
  final List<Grade> allGrades;
  final List<AttendanceRecord> attendance;
  final List<TeachingAssistant> teachingAssistants;
  final LoadingState loadingState;
  final int currentSemester;
  final String currentAcademicYear;

  const DataState({
    this.students = const [],
    this.doctors = const [],
    this.subjects = const [],
    this.lectures = const [],
    this.allSubjects = const [],
    this.allLectures = const [],
    this.allSections = const [], // ← جديد
    this.grades = const [],
    this.allGrades = const [],
    this.attendance = const [],
    this.teachingAssistants = const [],
    this.loadingState = const LoadingState(),
    this.currentSemester = 1,
    this.currentAcademicYear = '2026-2027',
  });

  DataState copyWith({
    List<Student>? students,
    List<Doctor>? doctors,
    List<Subject>? subjects,
    List<Lecture>? lectures,
    List<Subject>? allSubjects,
    List<Lecture>? allLectures,
    List<Section>? allSections, // ← جديد
    List<Grade>? grades,
    List<Grade>? allGrades,
    List<AttendanceRecord>? attendance,
    List<TeachingAssistant>? teachingAssistants,
    LoadingState? loadingState,
    int? currentSemester,
    String? currentAcademicYear,
  }) {
    return DataState(
      students: students ?? this.students,
      doctors: doctors ?? this.doctors,
      subjects: subjects ?? this.subjects,
      lectures: lectures ?? this.lectures,
      allSubjects: allSubjects ?? this.allSubjects,
      allLectures: allLectures ?? this.allLectures,
      allSections: allSections ?? this.allSections, // ← جديد
      grades: grades ?? this.grades,
      allGrades: allGrades ?? this.allGrades,
      attendance: attendance ?? this.attendance,
      teachingAssistants: teachingAssistants ?? this.teachingAssistants,
      loadingState: loadingState ?? this.loadingState,
      currentSemester: currentSemester ?? this.currentSemester,
      currentAcademicYear: currentAcademicYear ?? this.currentAcademicYear,
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
        allSections, // ← جديد
        grades,
        allGrades,
        attendance,
        teachingAssistants,
        loadingState,
        currentSemester,
        currentAcademicYear,
      ];

  // ── Helper methods ────────────────────────────────────────────────────────

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

  /// السكاشن الخاصة بطالب معين حسب level + department
  List<Section> getSectionsForStudent(Student student) {
    return allSections
        .where((s) =>
            s.level == student.level &&
            (s.department == null || s.department == student.department))
        .toList();
  }

  List<Grade> getGradesForStudentAndSemester(int studentId, int semester) {
    return allGrades
        .where((g) =>
            g.studentId == studentId &&
            g.semester == semester &&
            g.isVisible)
        .toList();
  }

  List<Grade> getAllGradesForStudent(int studentId) {
    return allGrades
        .where((g) => g.studentId == studentId && g.isVisible)
        .toList();
  }

  String get semesterDisplay =>
      currentSemester == 1 ? 'First Semester' : 'Second Semester';

  // ── Factories ─────────────────────────────────────────────────────────────

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
    List<Section>? allSections, // ← جديد
    int? currentSemester,
    String? currentAcademicYear, required List<TeachingAssistant> teachingAssistants,
  }) =>
      DataState(
        students: students,
        doctors: doctors,
        subjects: subjects,
        lectures: lectures,
        allSubjects: allSubjects ?? subjects,
        allLectures: allLectures ?? lectures,
        allSections: allSections ?? const [], // ← جديد
        currentSemester: currentSemester ?? 1,
        currentAcademicYear: currentAcademicYear ?? '2026-2027',
        loadingState: LoadingState.loaded(),
      );

  factory DataState.error(String message) => DataState(
        loadingState: LoadingState.error(message),
      );
}
