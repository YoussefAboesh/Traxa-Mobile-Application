import '../core/api_service.dart';
import '../core/result/result.dart';
import 'base_repository.dart';

class SystemRepository extends BaseRepository {
  static const _tag = 'SystemRepository';

  Future<Result<int>> getCurrentSemester() =>
      guard(() => ApiService.getCurrentSemester(), tag: _tag);

  Future<Result<String>> getCurrentAcademicYear() =>
      guard(() => ApiService.getCurrentAcademicYear(), tag: _tag);

  Future<Result<Map<String, dynamic>>> getAcademicSettings(String token) =>
      guard(() => ApiService.getAcademicSettings(token), tag: _tag);

  Future<Result<List<dynamic>>> getSections() =>
      guard(() => ApiService.getSections(), tag: _tag);

  Future<Result<List<dynamic>>> getSectionsBySemester(int semester) =>
      guard(() => ApiService.getSectionsBySemester(semester), tag: _tag);
}
