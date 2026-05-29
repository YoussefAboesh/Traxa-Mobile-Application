import '../core/api_service.dart';
import '../core/result/result.dart';
import 'base_repository.dart';

class StudentRepository extends BaseRepository {
  static const _tag = 'StudentRepository';

  Future<Result<List<dynamic>>> getAllStudents() =>
      guard(() => ApiService.getStudents(), tag: _tag);

  Future<Result<List<dynamic>>> getPublicStudents() =>
      guard(() => ApiService.getStudentsPublic(), tag: _tag);

  Future<Result<Map<String, dynamic>>> changePassword({
    required String studentId,
    required String newPassword,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.changeStudentPassword(
        studentId,
        newPassword,
        token,
      );
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<Map<String, dynamic>>> getQrCode({
    required int studentId,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.getStudentQRCode(studentId, token);
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<Map<String, dynamic>>> recordQrScan({
    required int studentId,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.recordQRCodeScan(studentId, token);
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<Map<String, dynamic>>> getEnrollmentStatus({
    required int studentId,
    required String token,
  }) =>
      guard(() => ApiService.getStudentEnrollmentStatus(studentId, token),
          tag: _tag);

  Future<Result<Map<String, dynamic>>> getAvailableSubjects({
    required int studentId,
    required int semester,
    required String token,
  }) =>
      guard(
          () => ApiService.getAvailableSubjectsForEnrollment(
              studentId, semester, token),
          tag: _tag);

  Future<Result<Map<String, dynamic>>> registerForSubject({
    required Map<String, dynamic> enrollmentData,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.registerForSubject(enrollmentData, token);
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<Map<String, dynamic>>> dropSubject({
    required Map<String, dynamic> dropData,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.dropSubject(dropData, token);
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }
}
