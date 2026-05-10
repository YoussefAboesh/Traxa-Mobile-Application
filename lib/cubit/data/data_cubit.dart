// lib/cubit/data/data_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_service.dart';
import '../../models/student.dart';
import '../../models/doctor.dart';
import '../../models/subject.dart';
import '../../models/lecture.dart';
import '../../models/grade.dart';
import '../../models/attendance.dart';
import '../../models/teaching_assistant.dart';
import 'data_state.dart';

class DataCubit extends Cubit<DataState> {
  DataCubit() : super(DataState.initial()) {
    loadSystemData();
  }

  int _currentSemester = 1;
  String _currentAcademicYear = '2026-2027';

  int get currentSemester => _currentSemester;
  String get currentAcademicYear => _currentAcademicYear;

  Future<void> loadSystemData() async {
    try {
      await loadCurrentSemester();
      await loadCurrentAcademicYear();
      if (_currentSemester != state.currentSemester ||
          _currentAcademicYear != state.currentAcademicYear) {
        emit(state.copyWith(
          currentSemester: _currentSemester,
          currentAcademicYear: _currentAcademicYear,
        ));
      }
      print('✅ System data: S$_currentSemester / $_currentAcademicYear');
    } catch (e) {
      print('❌ Error loading system data: $e');
    }
  }

  Future<void> loadCurrentSemester() async {
    try {
      _currentSemester = await ApiService.getCurrentSemester();
      print('📅 Semester: $_currentSemester');
    } catch (e) {
      print('❌ Error loading semester: $e');
      _currentSemester = 1;
    }
  }

  Future<void> loadCurrentAcademicYear() async {
    try {
      _currentAcademicYear = await ApiService.getCurrentAcademicYear();
      print('📅 Academic year: $_currentAcademicYear');
    } catch (e) {
      print('❌ Error loading academic year: $e');
      _currentAcademicYear = '2026-2027';
    }
  }

  Future<void> loadAllData() async {
    if (state.loadingState.isLoading) return;

    emit(DataState.loading());

    try {
      await loadCurrentSemester();
      await loadCurrentAcademicYear();

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

      // (verbose breakdown removed — see "Data loaded" line below)

      emit(DataState.loaded(
        students: allStudents,
        doctors: allDoctors,
        subjects: filteredSubjects,
        lectures: filteredLectures,
        allSubjects: allSubjects,
        allLectures: allLectures,
        currentSemester: _currentSemester,
        currentAcademicYear: _currentAcademicYear,
      ));

      print('✅ Data loaded');
    } catch (e) {
      emit(DataState.error('Failed to load data: ${e.toString()}'));
      print('❌ Error loading data: $e');
    }
  }

  // ✅ Full reload - fetches all data fresh from server with token check
  Future<void> fullReload() async {
    print('🔄 DataCubit: Full reload started...');
    
    // ✅ التأكد من وجود توكن صالح قبل البدء
    final token = ApiService.getToken();
    if (token == null || token.isEmpty) {
      print('❌ No valid token available for full reload');
      emit(DataState.error('Session expired. Please login again.'));
      return;
    }
    
    try {
      await loadCurrentSemester();
      await loadCurrentAcademicYear();

      print('📅 Fetching data for Semester: $_currentSemester, Year: $_currentAcademicYear');

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

      // verbose count removed

      final filteredSubjects =
          allSubjects.where((s) => s.semester == _currentSemester).toList();

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

      print('✅ Data loaded');

      emit(DataState.loaded(
        students: allStudents,
        doctors: allDoctors,
        subjects: filteredSubjects,
        lectures: filteredLectures,
        allSubjects: allSubjects,
        allLectures: allLectures,
        currentSemester: _currentSemester,
        currentAcademicYear: _currentAcademicYear,
      ));
    } catch (e) {
      print('❌ Full reload error: $e');
      
      // ✅ في حالة خطأ 401 (Unauthorized)، فلنخرج المستخدم
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        emit(DataState.error('Session expired. Please login again.'));
      } else {
        emit(DataState.error('Failed to reload data: ${e.toString()}'));
      }
    }
  }

  // ✅ Grades are NOT filtered by semester - student can choose any semester
  Future<void> loadStudentGrades(int studentId) async {
    try {
      final response = await ApiService.getStudentGrades(studentId);
      final allGrades = response.map((j) => Grade.fromJson(j)).toList();

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

  List<Grade> getGradesForSemester(int semester) {
    return state.allGrades.where((g) => g.semester == semester).toList();
  }

  Future<void> checkGradesStatus(int studentId, String token) async {
    try {
      await ApiService.checkGradesStatus(studentId, token);
      print('📊 Grades loaded');
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

  Future<void> fetchTAsForDoctor(int doctorId) async {
    try {
      final response =
          await ApiService.getTeachingAssistantsForDoctor(doctorId);
      final tas = response.map((j) => TeachingAssistant.fromJson(j)).toList();
      emit(state.copyWith(teachingAssistants: tas));
      print('👥 TAs loaded for doctor $doctorId: ${tas.length}');
    } catch (e) {
      print('❌ Error loading TAs: $e');
    }
  }

  Future<Map<String, dynamic>> fetchTAPermissions(int taId) async {
    return await ApiService.getTAPermissions(taId);
  }

  Future<Map<String, dynamic>> updateTAPermissions(
      int taId, Map<String, dynamic> permissions) async {
    final result = await ApiService.updateTAPermissions(taId, permissions);
    if (result['success'] == true) {
      final updated = state.teachingAssistants.map((ta) {
        if (ta.id == taId) {
          return TeachingAssistant(
            id: ta.id,
            name: ta.name,
            username: ta.username,
            email: ta.email,
            supervisorDoctorId: ta.supervisorDoctorId,
            permissions: permissions,
          );
        }
        return ta;
      }).toList();
      emit(state.copyWith(teachingAssistants: updated));
    }
    return result;
  }

  Future<void> refreshForNewSemester() async {
    print('🔄 Refreshing data for new semester...');
    await loadCurrentSemester();
    await loadAllData();
  }

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