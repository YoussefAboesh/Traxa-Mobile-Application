// lib/cubit/data/data_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_service.dart';
import '../../models/student.dart';
import '../../models/doctor.dart';
import '../../models/subject.dart';
import '../../models/lecture.dart';
import '../../models/grade.dart';
import '../../models/attendance.dart';
import 'data_state.dart';

class DataCubit extends Cubit<DataState> {
  DataCubit() : super(DataState.initial());

  int _currentSemester = 1;

  int get currentSemester => _currentSemester;

  Future<void> loadCurrentSemester() async {
    try {
      _currentSemester = await ApiService.getCurrentSemester();
      print('📅 Current semester loaded: $_currentSemester');
    } catch (e) {
      print('❌ Error loading semester: $e');
      _currentSemester = 1;
    }
  }

  Future<void> loadAllData() async {
    if (state.loadingState.isLoading) return;

    emit(DataState.loading());

    try {
      await loadCurrentSemester();

      final results = await Future.wait([
        ApiService.getStudents(),
        ApiService.getDoctors(),
        ApiService.getSubjects(),
        ApiService.getLectures(),
      ]);

      final allStudents = results[0].map((j) => Student.fromJson(j)).toList();
      final allDoctors = results[1].map((j) => Doctor.fromJson(j)).toList();
      final allSubjects = results[2].map((j) => Subject.fromJson(j)).toList();
      final allLectures = results[3].map((j) => Lecture.fromJson(j)).toList();

      // ✅ Filter subjects by current semester
      final filteredSubjects =
          allSubjects.where((s) => s.semester == _currentSemester).toList();

      // ✅ Filter lectures by current semester (via subject semester)
      final filteredLectures = allLectures.where((l) {
        final subject = allSubjects.firstWhere(
          (s) => s.id == l.subjectId,
          orElse: () => Subject(
              id: 0,
              name: '',
              doctorId: 0,
              doctorName: '',
              level: 1,
              semester: 1),
        );
        return subject.semester == _currentSemester;
      }).toList();

      print('=' * 50);
      print('📅 CURRENT SEMESTER: $_currentSemester');
      print('📚 SUBJECTS (all): ${allSubjects.length}');
      print(
          '📚 SUBJECTS (filtered for S$_currentSemester): ${filteredSubjects.length}');
      print('🎓 LECTURES (all): ${allLectures.length}');
      print(
          '🎓 LECTURES (filtered for S$_currentSemester): ${filteredLectures.length}');
      print('=' * 50);

      emit(DataState.loaded(
        students: allStudents,
        doctors: allDoctors,
        subjects: filteredSubjects,
        lectures: filteredLectures,
        allSubjects: allSubjects,
        allLectures: allLectures,
        currentSemester: _currentSemester,
      ));

      print(
          '✅ Data loaded successfully (filtered by Semester $_currentSemester)');
    } catch (e) {
      emit(DataState.error('Failed to load data: ${e.toString()}'));
      print('❌ Error loading data: $e');
    }
  }

  // ✅ Grades are NOT filtered by semester - student can choose any semester
  Future<void> loadStudentGrades(int studentId) async {
    try {
      final response = await ApiService.getStudentGrades(studentId);
      final allGrades = response.map((j) => Grade.fromJson(j)).toList();

      // Store all grades without filtering
      emit(state.copyWith(allGrades: allGrades));
      print('📊 All grades loaded: ${allGrades.length}');
    } catch (e) {
      print('❌ Error loading grades: $e');
    }
  }

  Future<void> loadStudentGradesWithToken(int studentId, String token) async {
    print('📊 Loading grades for student $studentId with token');

    try {
      final response =
          await ApiService.getStudentGradesWithToken(studentId, token);
      final allGrades = response.map((j) => Grade.fromJson(j)).toList();

      print('✅ Loaded ${allGrades.length} grades (all semesters)');

      emit(state.copyWith(allGrades: allGrades));
    } catch (e) {
      print('❌ Error loading grades: $e');
    }
  }

  // ✅ Get filtered grades by semester (for display)
  List<Grade> getGradesForSemester(int semester) {
    return state.allGrades.where((g) => g.semester == semester).toList();
  }

  Future<void> checkGradesStatus(int studentId, String token) async {
    try {
      final status = await ApiService.checkGradesStatus(studentId, token);
      print('📊 Grades Status: $status');
    } catch (e) {
      print('❌ Error checking grades status: $e');
    }
  }

  Future<void> loadAttendance(String? token) async {
    try {
      final response = await ApiService.getAttendance(token);
      final attendance =
          response.map((j) => AttendanceRecord.fromJson(j)).toList();

      emit(state.copyWith(attendance: attendance));
      print('📋 Attendance loaded: ${attendance.length}');
    } catch (e) {
      print('❌ Error loading attendance: $e');
    }
  }

  void clearData() {
    emit(DataState.initial());
  }

  Future<void> refreshForNewSemester() async {
    print('🔄 Refreshing data for new semester...');
    await loadCurrentSemester();
    await loadAllData();
  }

  // ✅ Update grades from WebSocket
  void updateGrade(Grade updatedGrade) {
    final List<Grade> newGrades = List.from(state.allGrades);
    final index = newGrades.indexWhere((g) => g.id == updatedGrade.id);
    if (index != -1) {
      newGrades[index] = updatedGrade;
    } else {
      newGrades.add(updatedGrade);
    }
    emit(state.copyWith(allGrades: newGrades));
    print(
        '📊 Grade updated in state: ${updatedGrade.subjectName} = ${updatedGrade.total}');
  }
}
