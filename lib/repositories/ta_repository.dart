import '../core/api_service.dart';
import '../core/result/result.dart';
import 'base_repository.dart';

class TaRepository extends BaseRepository {
  static const _tag = 'TaRepository';

  Future<Result<List<dynamic>>> getAll() =>
      guard(() => ApiService.getTeachingAssistants(), tag: _tag);

  Future<Result<List<dynamic>>> getForDoctor(int doctorId) =>
      guard(() => ApiService.getTeachingAssistantsForDoctor(doctorId),
          tag: _tag);

  Future<Result<Map<String, dynamic>>> getPermissions(int taId) =>
      guard(() => ApiService.getTAPermissions(taId), tag: _tag);

  Future<Result<Map<String, dynamic>>> updatePermissions(
    int taId,
    Map<String, dynamic> permissions,
  ) async {
    return guard(() async {
      final res = await ApiService.updateTAPermissions(taId, permissions);
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }

  Future<Result<Map<String, dynamic>>> getSubjectPermissions({
    required int taId,
    required int subjectId,
    required String token,
  }) =>
      guard(() => ApiService.getTASubjectPermissions(taId, subjectId, token),
          tag: _tag);

  Future<Result<Map<String, dynamic>>> updateSubjectPermissions({
    required int taId,
    required int subjectId,
    required Map<String, dynamic> permissions,
    required String token,
  }) async {
    return guard(() async {
      final res = await ApiService.updateTASubjectPermissions(
        taId: taId,
        subjectId: subjectId,
        permissions: permissions,
        token: token,
      );
      return fromLegacyResponse(res)
          .when(success: (m) => m, failure: (e) => throw e);
    }, tag: _tag);
  }
}
