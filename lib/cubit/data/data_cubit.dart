import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/logger.dart';
import '../../models/attendance.dart';
import '../../models/doctor.dart';
import '../../models/grade.dart';
import '../../models/lecture.dart';
import '../../models/section.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../models/teaching_assistant.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/doctor_repository.dart';
import '../../repositories/grades_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/system_repository.dart';
import '../../repositories/ta_repository.dart';
import '../../services/cache_service.dart';
import '../shared/loading_state.dart';
import 'data_state.dart';

class DataCubit extends Cubit<DataState> {
  DataCubit({
    SystemRepository? systemRepo,
    StudentRepository? studentRepo,
    DoctorRepository? doctorRepo,
    GradesRepository? gradesRepo,
    AttendanceRepository? attendanceRepo,
    TaRepository? taRepo,
  })  : _system = systemRepo ?? getIt<SystemRepository>(),
        _studentRepo = studentRepo ?? getIt<StudentRepository>(),
        _doctorRepo = doctorRepo ?? getIt<DoctorRepository>(),
        _gradesRepo = gradesRepo ?? getIt<GradesRepository>(),
        _attendanceRepo = attendanceRepo ?? getIt<AttendanceRepository>(),
        _taRepo = taRepo ?? getIt<TaRepository>(),
        super(DataState.initial());

  final SystemRepository _system;
  final StudentRepository _studentRepo;
  final DoctorRepository _doctorRepo;
  final GradesRepository _gradesRepo;
  final AttendanceRepository _attendanceRepo;
  final TaRepository _taRepo;

  static const _tag = 'DataCubit';

  /// Bootstrap entry point — called by the service locator.
  Future<void> init() => loadSystemData();

  int _currentSemester = 1;
  String _currentAcademicYear = '2026-2027';

  int get currentSemester => _currentSemester;
  String get currentAcademicYear => _currentAcademicYear;

  Future<void> loadSystemData() async {
    await loadCurrentSemester();
    await loadCurrentAcademicYear();
    if (_currentSemester != state.currentSemester ||
        _currentAcademicYear != state.currentAcademicYear) {
      emit(state.copyWith(
        currentSemester: _currentSemester,
        currentAcademicYear: _currentAcademicYear,
      ));
    }
  }

  Future<void> loadCurrentSemester() async {
    final result = await _system.getCurrentSemester();
    result.when(
      success: (s) => _currentSemester = s,
      failure: (e) {
        AppLogger.w('Error loading semester', tag: _tag, error: e);
        _currentSemester = 1;
      },
    );
  }

  Future<void> loadCurrentAcademicYear() async {
    final result = await _system.getCurrentAcademicYear();
    result.when(
      success: (y) => _currentAcademicYear = y,
      failure: (e) {
        AppLogger.w('Error loading academic year', tag: _tag, error: e);
        _currentAcademicYear = '2026-2027';
      },
    );
  }

  List<Section> _extractSections(List<dynamic> rawSections) {
    final sections = <Section>[];
    for (final json in rawSections) {
      if (json is Map<String, dynamic>) {
        try {
          sections.add(Section.fromJson(json));
        } catch (_) {
          // Server occasionally returns rows missing required fields — skip them.
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
        orElse: () => const Subject(
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
      AppLogger.i('Loaded data from offline cache', tag: _tag);
      return true;
    } catch (e) {
      AppLogger.w('Error loading from cache', tag: _tag, error: e);
      return false;
    }
  }

  Future<void> _fetchAndEmit({required String errorPrefix}) async {
    emit(state.copyWith(loadingState: LoadingState.loading()));

    await loadCurrentSemester();
    await loadCurrentAcademicYear();

    final results = await Future.wait([
      _studentRepo.getAllStudents(),
      _doctorRepo.getAllDoctors(),
      _doctorRepo.getSubjects(),
      _doctorRepo.getLectures(),
      _system.getSections(),
      _taRepo.getAll(),
    ]);

    final anyFailed = results.any((r) => r.isFailure);
    if (anyFailed) {
      final firstFailure = results.firstWhere((r) => r.isFailure);
      final err = firstFailure.exceptionOrNull;
      AppLogger.w('$errorPrefix: ${err?.message}', tag: _tag);

      // Only fall back to error state if cache is also empty — keeps the
      // user on the last-known-good data when offline.
      final usedCache = await _emitFromCache();
      if (usedCache) return;

      final msg = err?.message ?? '';
      if (msg.toLowerCase().contains('unauthorized') ||
          msg.toLowerCase().contains('session expired')) {
        emit(DataState.error('Session expired. Please login again.'));
      } else {
        emit(DataState.error(
            'No internet connection and no offline data available.'));
      }
      return;
    }

    final students = results[0].valueOrNull ?? const [];
    final doctors = results[1].valueOrNull ?? const [];
    final subjects = results[2].valueOrNull ?? const [];
    final lectures = results[3].valueOrNull ?? const [];
    final sections = results[4].valueOrNull ?? const [];
    final tas = results[5].valueOrNull ?? const [];

    _emitLoaded(
      rawStudents: students,
      rawDoctors: doctors,
      rawSubjects: subjects,
      rawLectures: lectures,
      rawSections: sections,
      rawTAs: tas,
    );

    await CacheService.saveAllData(
      students: students,
      doctors: doctors,
      subjects: subjects,
      lectures: lectures,
    );
  }

  Future<void> loadAllData() async {
    if (state.loadingState.isLoading) return;
    await _fetchAndEmit(errorPrefix: 'Error loading data');
  }

  Future<void> fullReload() async {
    // Still reads the in-memory token from the legacy static facade; a
    // future pass will swap this for TokenHolder injected via GetIt.
    final token = ApiService.getToken();
    if (token == null || token.isEmpty) {
      emit(DataState.error('Session expired. Please login again.'));
      return;
    }
    await _fetchAndEmit(errorPrefix: 'Full reload error');
  }

  Future<void> loadStudentGrades(int studentId) async {
    final result = await _gradesRepo.getStudentGrades(studentId);
    result.when(
      success: (raw) {
        final grades = raw.map((j) => Grade.fromJson(j)).toList();
        emit(state.copyWith(allGrades: grades));
      },
      failure: (e) => AppLogger.w('Error loading grades', tag: _tag, error: e),
    );
  }

  Future<void> loadStudentGradesWithToken(int studentId, String token) async {
    final result = await _gradesRepo.getStudentGradesWithToken(studentId, token);
    result.when(
      success: (raw) {
        final grades = raw.map((j) => Grade.fromJson(j)).toList();
        emit(state.copyWith(allGrades: grades));
      },
      failure: (e) => AppLogger.w('Error loading grades', tag: _tag, error: e),
    );
  }

  List<Grade> getGradesForSemester(int semester) =>
      state.allGrades.where((g) => g.semester == semester).toList();

  Future<void> checkGradesStatus(int studentId, String token) async {
    final result = await _gradesRepo.checkStatus(studentId, token);
    result.when(
      success: (_) {},
      failure: (e) => AppLogger.w('Error checking grades status', tag: _tag, error: e),
    );
  }

  Future<void> loadAttendance(String? token) async {
    final result = await _attendanceRepo.getAll(token: token);
    result.when(
      success: (raw) {
        final records = raw.map((j) => AttendanceRecord.fromJson(j)).toList();
        emit(state.copyWith(attendance: records));
      },
      failure: (e) =>
          AppLogger.w('Error loading attendance', tag: _tag, error: e),
    );
  }

  void clearData() {
    emit(DataState.initial());
  }

  Future<void> fetchTAsForDoctor(int doctorId) async {
    final result = await _taRepo.getForDoctor(doctorId);
    result.when(
      success: (raw) {
        final tas = raw.map((j) => TeachingAssistant.fromJson(j)).toList();
        emit(state.copyWith(teachingAssistants: tas));
      },
      failure: (e) => AppLogger.w('Error loading TAs', tag: _tag, error: e),
    );
  }

  Future<Map<String, dynamic>> fetchTAPermissions(int taId) async {
    final result = await _taRepo.getPermissions(taId);
    return result.valueOrNull ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateTAPermissions(
    int taId,
    Map<String, dynamic> permissions,
  ) async {
    final result = await _taRepo.updatePermissions(taId, permissions);
    final asMap = result.valueOrNull;

    if (asMap != null) {
      final updated = state.teachingAssistants.map((ta) {
        if (ta.id == taId) return ta.copyWith(permissions: permissions);
        return ta;
      }).toList();
      emit(state.copyWith(teachingAssistants: updated));
      return {'success': true, ...asMap};
    }
    final err = result.exceptionOrNull;
    return {'success': false, 'error': err?.message ?? 'Failed'};
  }

  Future<void> refreshForNewSemester() async {
    await loadCurrentSemester();
    await loadAllData();
  }

  void updateGrade(Grade updatedGrade) {
    final newGrades = List<Grade>.from(state.allGrades);
    final index = newGrades.indexWhere((g) => g.id == updatedGrade.id);
    if (index != -1) {
      newGrades[index] = updatedGrade;
    } else {
      newGrades.add(updatedGrade);
    }
    emit(state.copyWith(allGrades: newGrades));
  }
}
