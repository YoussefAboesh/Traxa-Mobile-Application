import '../core/api_service.dart';
import '../core/result/result.dart';
import 'base_repository.dart';

class GradesRepository extends BaseRepository {
  static const _tag = 'GradesRepository';

  Future<Result<List<dynamic>>> getStudentGrades(int studentId) =>
      guard(() => ApiService.getStudentGrades(studentId), tag: _tag);

  Future<Result<List<dynamic>>> getStudentGradesWithToken(
    int studentId,
    String token,
  ) =>
      guard(() => ApiService.getStudentGradesWithToken(studentId, token),
          tag: _tag);

  Future<Result<Map<String, dynamic>>> checkStatus(
    int studentId,
    String token,
  ) =>
      guard(() => ApiService.checkGradesStatus(studentId, token), tag: _tag);

  Future<Result<Map<String, double>>> getDistribution({
    required int doctorId,
    required int subjectId,
    required String token,
  }) {
    return guard(() async {
      final dist = await ApiService.getGradeDistribution(doctorId, subjectId, token);
      // University default when the server has no row configured.
      return dist ??
          const {
            'midterm': 10,
            'oral': 5,
            'practical': 20,
            'attendance': 5,
            'assignment': 10,
            'final': 50,
          };
    }, tag: _tag);
  }
}
