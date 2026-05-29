import '../core/api_service.dart';
import '../core/result/result.dart';
import 'base_repository.dart';

class DoctorRepository extends BaseRepository {
  static const _tag = 'DoctorRepository';

  Future<Result<List<dynamic>>> getAllDoctors() =>
      guard(() => ApiService.getDoctors(), tag: _tag);

  Future<Result<List<dynamic>>> getPublicDoctors() =>
      guard(() => ApiService.getDoctorsPublic(), tag: _tag);

  Future<Result<List<dynamic>>> getSubjects() =>
      guard(() => ApiService.getSubjects(), tag: _tag);

  Future<Result<List<dynamic>>> getPublicSubjects() =>
      guard(() => ApiService.getSubjectsPublic(), tag: _tag);

  Future<Result<List<dynamic>>> getLectures() =>
      guard(() => ApiService.getLectures(), tag: _tag);

  Future<Result<List<dynamic>>> getLecturesBySemester(int semester) =>
      guard(() => ApiService.getLecturesBySemester(semester), tag: _tag);

  Future<Result<Map<String, dynamic>>> getQrCodes({
    required int doctorId,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.getDoctorQRCodes(doctorId, token);
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<Map<String, dynamic>>> assignTA({
    required int subjectId,
    required int taId,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.assignTAToSubject(
        subjectId: subjectId,
        taId: taId,
        token: token,
      );
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<Map<String, dynamic>>> removeTA({
    required int subjectId,
    required String token,
  }) async {
    return guard(() async {
      final res =
          await ApiService.removeTAFromSubject(subjectId: subjectId, token: token);
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<bool>> deleteAvatar({
    required String kind,
    required String id,
    required String token,
  }) =>
      guard(
          () => ApiService.forceRemoveAvatar(
              kind: kind, id: id, token: token),
          tag: _tag);
}
