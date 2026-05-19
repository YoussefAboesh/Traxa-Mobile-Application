import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_service.dart';
import '../../services/cache_service.dart';
import '../../models/student.dart';
import '../../models/doctor.dart';
import '../../models/subject.dart';
import '../../models/lecture.dart';
import '../../models/section.dart';
import '../../models/grade.dart';
import '../../models/attendance.dart';
import '../../models/teaching_assistant.dart';
import '../shared/loading_state.dart';
import 'data_state.dart';

class DataCubit extends Cubit<DataState> {
  DataCubit() : super(DataState.initial()) {
    loadSystemData();
  }

  int _currentSemester = 1;
  String _currentAcademicYear = '2026-2027';

  int get currentSemester => _currentSemester;
  String get currentAcademicYear => _currentAcademicYear;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

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
    } catch (e) {
      _log('❌ Error loading system data: $e');
    }
  }

  Future<void> loadCurrentSemester() async {
    try {
      _currentSemester = await ApiService.getCurrentSemester();
    } catch (e) {
      _log('❌ Error loading semester: $e');
      _currentSemester = 1;
    }
  }

  Future<void> loadCurrentAcademicYear() async {
    try {
      _currentAcademicYear = await ApiService.getCurrentAcademicYear();
    } catch (e) {
      _log('❌ Error loading academic year: $e');
      _currentAcademicYear = '2026-2027';
    }
  }

  List<Section> _extractSections(List<dynamic> rawSections) {
    final sections = <Section>[];
    for (final json in rawSections) {
      if (json is Map<String, dynamic>) {
        try {
          sections.add(Section.fromJson(json));
        } catch (_) {
          // skip malformed section
        }
      }
    }
    return sections;
  }

  void _emitLoaded({
    required List<dynamic> rawStudents,
    required List<dynamic> rawDoctors,
    required List<dynamic> rawSubjects,
    required List<dynamic> rawLectures,
    required List<dynamic> rawSections,
    required List<dynamic> rawTAs,
  }) {
    final allStudents = rawStudents.map((j) => Student.fromJson(j)).toList();
    final allDoctors = rawDoctors.map((j) => Doctor.fromJson(j)).toList();
    final allSubjects = rawSubjects.map((j) => Subject.fromJson(j)).toList();
    final allLectures = rawLectures.map((j) => Lecture.fromJson(j)).toList();
    final allSections = _extractSections(rawSections);
    final allTAs = rawTAs.map((j) => TeachingAssistant.fromJson(j)).toList();

    final filteredSubjects =
        allSubjects.where((s) => s.semester == _currentSemester).toList();

    final filteredLectures = allLectures.where((l) {
      final subject = allSubjects.firstWhere(
        (s) => s.id == l.subjectId,
        orElse: () => Subject(
            id: 0, name: '', doctorId: 0, doctorName: '', level: 1, semester: 1),
      );
      return subject.semester == _currentSemester;
    }).toList();

    emit(DataState.loaded(
      students: allStudents,
      doctors: allDoctors,
      subjects: filteredSubjects,
      lectures: filteredLectures,
      allSubjects: allSubjects,
      allLectures: allLectures,
      allSections: allSections,
      teachingAssistants: allTAs,
      currentSemester: _currentSemester,
      currentAcademicYear: _currentAcademicYear,
    ));
  }

  Future<bool> _emitFromCache() async {
    try {
      final cached = await CacheService.loadAllData(ignoreExpiry: true);
      if (cached == null) return false;
      _emitLoaded(
        rawStudents: cached['students'] ?? [],
        rawDoctors: cached['doctors'] ?? [],
        rawSubjects: cached['subjects'] ?? [],
        rawLectures: cached['lectures'] ?? [],
        rawSections: const [],
        rawTAs: const [],
      );
      _log('📦 Loaded data from offline cache');
      return true;
    } catch (e) {
      _log('❌ Error loading from cache: $e');
      return false;
    }
  }

  Future<void> _fetchAndEmit({required String errorPrefix}) async {
    emit(state.copyWith(loadingState: LoadingState.loading()));

    try {
      await loadCurrentSemester();
      await loadCurrentAcademicYear();

      final results = await Future.wait([
        ApiService.getStudents(),
        ApiService.getDoctors(),
        ApiService.getSubjects(),
        ApiService.getLectures(),
        ApiService.getSections(),
        ApiService.getTeachingAssistants(),
      ]);

      _emitLoaded(
        rawStudents: results[0],
        rawDoctors: results[1],
        rawSubjects: results[2],
        rawLectures: results[3],
        rawSections: results[4],
        rawTAs: results[5],
      );

      await CacheService.saveAllData(
        students: results[0],
        doctors: results[1],
        subjects: results[2],
        lectures: results[3],
      );
    } catch (e) {
      _log('❌ $errorPrefix: $e');

      final usedCache = await _emitFromCache();
      if (usedCache) return;

      if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        emit(DataState.error('Session expired. Please login again.'));
      } else {
        emit(DataState.error(
            'No internet connection and no offline data available.'));
      }
    }
  }

  Future<void> loadAllData() async {
    if (state.loadingState.isLoading) return;
    await _fetchAndEmit(errorPrefix: 'Error loading data');
  }

  Future<void> fullReload() async {
    final token = ApiService.getToken();
    if (token == null || token.isEmpty) {
      emit(DataState.error('Session expired. Please login again.'));
      return;
    }
    await _fetchAndEmit(errorPrefix: 'Full reload error');
  }

  // ── Grades ────────────────────────────────────────────────────────────────

  Future<void> loadStudentGrades(int studentId) async {
    try {
      final response = await ApiService.getStudentGrades(studentId);
      final allGrades = response.map((j) => Grade.fromJson(j)).toList();
      emit(state.copyWith(allGrades: allGrades));
    } catch (e) {
      _log('❌ Error loading grades: $e');
    }
  }

  Future<void> loadStudentGradesWithToken(int studentId, String token) async {
    try {
      final response =
          await ApiService.getStudentGradesWithToken(studentId, token);
      final allGrades = response.map((j) => Grade.fromJson(j)).toList();
      emit(state.copyWith(allGrades: allGrades));
    } catch (e) {
      _log('❌ Error loading grades: $e');
    }
  }

  List<Grade> getGradesForSemester(int semester) {
    return state.allGrades.where((g) => g.semester == semester).toList();
  }

  Future<void> checkGradesStatus(int studentId, String token) async {
    try {
      await ApiService.checkGradesStatus(studentId, token);
    } catch (e) {
      _log('❌ Error checking grades status: $e');
    }
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  Future<void> loadAttendance(String? token) async {
    try {
      final response = await ApiService.getAttendance(token);
      final attendance =
          response.map((j) => AttendanceRecord.fromJson(j)).toList();
      emit(state.copyWith(attendance: attendance));
    } catch (e) {
      _log('❌ Error loading attendance: $e');
    }
  }

  void clearData() {
    emit(DataState.initial());
  }

  // ── Teaching Assistants ───────────────────────────────────────────────────

  Future<void> fetchTAsForDoctor(int doctorId) async {
    try {
      final response = await ApiService.getTeachingAssistantsForDoctor(doctorId);
      final tas = response.map((j) => TeachingAssistant.fromJson(j)).toList();
      emit(state.copyWith(teachingAssistants: tas));
    } catch (e) {
      _log('❌ Error loading TAs: $e');
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
            assignedSubjectIds: ta.assignedSubjectIds,
          );
        }
        return ta;
      }).toList();
      emit(state.copyWith(teachingAssistants: updated));
    }
    return result;
  }

  Future<void> refreshForNewSemester() async {
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
  }
}
