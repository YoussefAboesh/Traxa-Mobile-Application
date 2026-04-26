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
  final List<Grade> grades;
  final List<AttendanceRecord> attendance;
  final LoadingState loadingState;
  
  const DataState({
    this.students = const [],
    this.doctors = const [],
    this.subjects = const [],
    this.lectures = const [],
    this.grades = const [],
    this.attendance = const [],
    this.loadingState = const LoadingState(),
  });
  
  DataState copyWith({
    List<Student>? students,
    List<Doctor>? doctors,
    List<Subject>? subjects,
    List<Lecture>? lectures,
    List<Grade>? grades,
    List<AttendanceRecord>? attendance,
    LoadingState? loadingState,
  }) {
    return DataState(
      students: students ?? this.students,
      doctors: doctors ?? this.doctors,
      subjects: subjects ?? this.subjects,
      lectures: lectures ?? this.lectures,
      grades: grades ?? this.grades,
      attendance: attendance ?? this.attendance,
      loadingState: loadingState ?? this.loadingState,
    );
  }
  
  @override
  List<Object?> get props => [
    students, doctors, subjects, lectures, grades, attendance, loadingState
  ];
  
  // Helper methods
  List<Subject> getSubjectsForDoctor(int doctorId) {
    return subjects.where((s) => s.doctorId == doctorId).toList();
  }
  
  List<Lecture> getLecturesForDoctor(int doctorId) {
    return lectures.where((l) => l.doctorId == doctorId).toList();
  }
  
  List<Subject> getSubjectsForStudent(Student student) {
    return subjects.where((s) => 
      s.level == student.level && 
      s.department == student.department
    ).toList();
  }
  
  List<Lecture> getLecturesForStudent(Student student) {
    return lectures.where((l) => 
      l.level == student.level && 
      l.department == student.department
    ).toList();
  }
  
  List<Grade> getGradesForStudent(int studentId) {
    return grades.where((g) => g.studentId == studentId && g.isVisible).toList();
  }
  
  factory DataState.initial() => const DataState();
  factory DataState.loading() => DataState(loadingState: LoadingState.loading());
  factory DataState.loaded({
    required List<Student> students,
    required List<Doctor> doctors,
    required List<Subject> subjects,
    required List<Lecture> lectures,
  }) => DataState(
    students: students,
    doctors: doctors,
    subjects: subjects,
    lectures: lectures,
    loadingState: LoadingState.loaded(),
  );
  factory DataState.error(String message) => DataState(
    loadingState: LoadingState.error(message),
  );
}