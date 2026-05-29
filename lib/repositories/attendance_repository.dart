import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_service.dart';
import '../core/constants/api_endpoints.dart';
import '../core/env/app_env.dart';
import '../core/exceptions/app_exception.dart';
import '../core/result/result.dart';
import 'base_repository.dart';

/// Wraps every attendance / session / report HTTP call so screens never touch
/// `http.*` directly. Each method returns a typed [Result] with proper
/// network / timeout / server-error handling via [BaseRepository.guard].
class AttendanceRepository extends BaseRepository {
  static const _tag = 'AttendanceRepository';
  static const _defaultTimeout = Duration(seconds: 10);

  String get _base => AppEnv.baseUrl;

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── Legacy passthrough used by DataCubit ───────────────────────────────
  Future<Result<List<dynamic>>> getAll({String? token}) =>
      guard(() => ApiService.getAttendance(token), tag: _tag);

  // ── Host listener / camera ─────────────────────────────────────────────

  /// Pings the server's camera-request endpoint. The server broadcasts the
  /// payload to every connected host-listener WebSocket and reports whether
  /// any host received it via `success: true|false` in the body.
  ///
  /// Fires the camera-request broadcast. The server forwards it to every
  /// connected WebSocket and the host-listener page opens the camera window
  /// in response. The server's `success` flag is unreliable on this build
  /// (it counts every WS client as a host), so we don't gate on it here —
  /// the caller verifies via [waitForCameraStarted] that the camera page
  /// actually came online.
  Future<Result<void>> requestCameraHost({
    required String token,
    required String sessionId,
    required int lectureId,
    required String doctorName,
  }) =>
      guard(() async {
        await http
            .post(
              Uri.parse('$_base${ApiEndpoints.cameraRequest}'),
              headers: _authHeaders(token),
              body: jsonEncode({
                'sessionId': sessionId,
                'lectureId': lectureId,
                'doctorName': doctorName,
              }),
            )
            .timeout(_defaultTimeout);
      }, tag: _tag);

  /// Polls `/api/attendance-sessions/:sessionId` — the camera page POSTs
  /// there as one of its first startup steps — to confirm the camera
  /// actually opened on the host machine. Returns `true` if the camera
  /// registered before [timeout], `false` otherwise.
  ///
  /// This is the authoritative "is the camera actually running?" check
  /// because the precheck via `/api/camera/request` can't tell whether
  /// the host page is open or whether its popup blocker swallowed the
  /// camera window.
  /// Default 90 s — the camera page calls `createSessionOnServer()` only
  /// after face-api models finish downloading from the GitHub CDN, which
  /// regularly takes 30-60 s on a typical campus network.
  Future<bool> waitForCameraStarted({
    required Object sessionId,
    required String token,
    Duration timeout = const Duration(seconds: 90),
    Duration interval = const Duration(milliseconds: 500),
    void Function(Duration elapsed)? onTick,
  }) async {
    final start = DateTime.now();
    final deadline = start.add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await http
            .get(
              Uri.parse('$_base${ApiEndpoints.attendanceSession(sessionId)}'),
              headers: _authHeaders(token),
            )
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) return true;
      } catch (_) {}
      onTick?.call(DateTime.now().difference(start));
      await Future.delayed(interval);
    }
    return false;
  }

  // ── Active sessions ────────────────────────────────────────────────────

  Future<Result<Map<String, dynamic>>> beginQrPhase({
    required Object sessionId,
    required String token,
    int durationMinutes = 30,
  }) =>
      guard(() async {
        final res = await http
            .post(
              Uri.parse('$_base${ApiEndpoints.activeSessionBeginQr(sessionId)}'),
              headers: _authHeaders(token),
              body: jsonEncode({'durationMinutes': durationMinutes}),
            )
            .timeout(_defaultTimeout);
        return _decodeJsonMap(res);
      }, tag: _tag);

  /// Returns the server's status code so callers can branch on 404 ("already
  /// closed elsewhere") vs 200/204.
  Future<Result<int>> deleteSession({
    required Object sessionId,
    required String token,
    Duration timeout = _defaultTimeout,
  }) =>
      guard(() async {
        final res = await http
            .delete(
              Uri.parse('$_base${ApiEndpoints.activeSession(sessionId)}'),
              headers: _authHeaders(token),
            )
            .timeout(timeout);
        return res.statusCode;
      }, tag: _tag);

  /// Fire-and-forget — the caller decides whether to await; errors are
  /// swallowed inside [Result] so a flaky network doesn't crash the screen.
  Future<Result<void>> heartbeat({
    required Object sessionId,
    required String token,
  }) =>
      guard(() async {
        await http.post(
          Uri.parse('$_base${ApiEndpoints.activeSessionHeartbeat(sessionId)}'),
          headers: _authHeaders(token),
        );
      }, tag: _tag);

  Future<Result<Map<String, dynamic>>> getSessionData({
    required Object sessionId,
    required String token,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      guard(() async {
        final res = await http
            .get(
              Uri.parse('$_base${ApiEndpoints.attendanceSessionData(sessionId)}'),
              headers: _authHeaders(token),
            )
            .timeout(timeout);
        if (res.statusCode == 404) {
          throw const ServerException('Session not found', statusCode: 404);
        }
        return _decodeJsonMap(res);
      }, tag: _tag);

  Future<Result<void>> pushSessionData({
    required Object sessionId,
    required String token,
    required List<Map<String, dynamic>> records,
    required List<Map<String, dynamic>> pending,
  }) =>
      guard(() async {
        await http
            .post(
              Uri.parse('$_base${ApiEndpoints.attendanceSessionData(sessionId)}'),
              headers: _authHeaders(token),
              body: jsonEncode({
                'records': records,
                'pending': pending,
                'lastUpdate': DateTime.now().toIso8601String(),
              }),
            )
            .timeout(const Duration(seconds: 8));
      }, tag: _tag);

  // ── Reports ────────────────────────────────────────────────────────────

  Future<Result<List<Map<String, dynamic>>>> listReportsByDoctor({
    required Object doctorId,
    required String token,
  }) =>
      guard(() async {
        final res = await http
            .get(
              Uri.parse('$_base${ApiEndpoints.attendanceReportsByDoctor(doctorId)}'),
              headers: _authHeaders(token),
            )
            .timeout(_defaultTimeout);
        if (res.statusCode != 200) {
          throw ServerException('Failed to load reports',
              statusCode: res.statusCode);
        }
        final raw = jsonDecode(res.body);
        if (raw is! List) return <Map<String, dynamic>>[];
        return raw
            .cast<Map<String, dynamic>>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }, tag: _tag);

  Future<Result<Map<String, dynamic>>> saveReport({
    required String token,
    required Map<String, dynamic> report,
  }) =>
      guard(() async {
        final res = await http
            .post(
              Uri.parse('$_base${ApiEndpoints.attendanceReports}'),
              headers: _authHeaders(token),
              body: jsonEncode(report),
            )
            .timeout(_defaultTimeout);
        if (res.statusCode != 200) {
          throw ServerException('Failed to save report',
              statusCode: res.statusCode);
        }
        return _decodeJsonMap(res);
      }, tag: _tag);

  Future<Result<Map<String, dynamic>>> getReportBySession({
    required Object sessionId,
    required String token,
  }) =>
      guard(() async {
        final res = await http
            .get(
              Uri.parse('$_base${ApiEndpoints.attendanceReportBySession(sessionId)}'),
              headers: _authHeaders(token),
            )
            .timeout(_defaultTimeout);
        if (res.statusCode != 200) {
          throw ServerException('Failed to fetch report',
              statusCode: res.statusCode);
        }
        return _decodeJsonMap(res);
      }, tag: _tag);

  Future<Result<void>> deleteReport({
    required Object reportId,
    required String token,
  }) =>
      guard(() async {
        final res = await http
            .delete(
              Uri.parse('$_base${ApiEndpoints.attendanceReportById(reportId)}'),
              headers: _authHeaders(token),
            )
            .timeout(_defaultTimeout);
        if (res.statusCode != 200) {
          throw ServerException('Delete failed',
              statusCode: res.statusCode);
        }
      }, tag: _tag);

  // ── Subjects / enrollment (used by reports filter) ────────────────────

  Future<Result<List<Map<String, dynamic>>>> listSubjects({
    required String token,
  }) =>
      guard(() async {
        final res = await http
            .get(
              Uri.parse('$_base${ApiEndpoints.subjects}'),
              headers: _authHeaders(token),
            )
            .timeout(_defaultTimeout);
        if (res.statusCode != 200) return <Map<String, dynamic>>[];
        final raw = jsonDecode(res.body);
        return raw is List ? raw.cast<Map<String, dynamic>>() : const [];
      }, tag: _tag);

  Future<Result<List<dynamic>>> getEnrolledStudents({
    required int subjectId,
    required String token,
  }) =>
      guard(() async {
        final res = await http
            .get(
              Uri.parse('$_base${ApiEndpoints.subjectEnrolledStudents(subjectId)}'),
              headers: _authHeaders(token),
            )
            .timeout(_defaultTimeout);
        if (res.statusCode != 200) return const [];
        final raw = jsonDecode(res.body);
        if (raw is Map && raw['students'] is List) {
          return raw['students'] as List;
        }
        return const [];
      }, tag: _tag);

  // ── helpers ────────────────────────────────────────────────────────────

  Map<String, dynamic> _decodeJsonMap(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ServerException('HTTP ${res.statusCode}',
          statusCode: res.statusCode);
    }
    final raw = jsonDecode(res.body);
    return raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
  }
}
