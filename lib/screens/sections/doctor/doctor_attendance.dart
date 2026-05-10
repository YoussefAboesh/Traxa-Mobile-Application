// lib/screens/sections/doctor/doctor_attendance.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/lecture.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';
import '../../../core/constants.dart';
import '../../../services/websocket_service.dart';

enum SessionPhase { none, active, confirming }

class DoctorAttendance extends StatefulWidget {
  const DoctorAttendance({super.key});

  @override
  State<DoctorAttendance> createState() => _DoctorAttendanceState();
}

class _DoctorAttendanceState extends State<DoctorAttendance>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Filters
  String _selectedDay = '';
  bool _showActiveSessions = false;
  int _selectedLevel = 0;

  // Session
  SessionPhase _phase = SessionPhase.none;
  Lecture? _activeSession;
  String? _activeSessionId;
  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;
  // The actual moment the lecturer pressed "End Lecture (Start QR)".
  // Distinct from _sessionEndTime, which doubles as the QR phase deadline
  // (30 minutes later) for the countdown timer. This one is what goes into
  // the saved report's endTime so the report shows real lecture duration.
  DateTime? _lectureEndedAt;
  List<Student>? _sessionStudents;
  bool _showStudentList = false;
  bool _isActivating = false;
  bool _isCameraOpen = false;
  bool _isFinalizing = false;

  // Live attendance
  List<Map<String, dynamic>> _attendanceRecords = [];
  int _confirmedCount = 0;
  int _pendingCount = 0;

  // Timers
  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  Timer? _confirmTimer;
  Timer? _syncTimer;
  Duration _confirmRemaining = Duration.zero;

  bool _didCheckServer = false;

  // ✅ Cache for enrolled students
  final Map<int, List<Student>> _enrolledStudentsCache = {};
  final Map<int, DateTime> _cacheTimestamp = {};
  final Duration _cacheDuration = Duration(minutes: 5);

  final List<String> _days = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday'
  ];
  final List<int> _levels = [1, 2, 3, 4];
  static const _qrDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithServer();
    });
    _setupWebSocketListeners();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _pollTimer?.cancel();
    _confirmTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  // ============================================
  // Cache Management
  // ============================================
  void _clearEnrolledStudentsCache() {
    _enrolledStudentsCache.clear();
    _cacheTimestamp.clear();
    print('🗑️ Enrolled students cache cleared');
  }

  // ============================================
  // Refresh Data (Pull-to-Refresh)
  // ============================================
  Future<void> _refreshData() async {
    if (_isActivating) return;
    _clearEnrolledStudentsCache();
    setState(() => _didCheckServer = false);
    await _tryRestoreSession();
    // ignore: use_build_context_synchronously
    await context.read<DataCubit>().loadAllData();
  }

  // ============================================
  // WebSocket Listeners for Real-time Sync
  // ============================================
  void _setupWebSocketListeners() {
    final ws = WebSocketService.instance;

    // Any session event → immediately sync with server (source of truth)
    ws.sessionActivatedStream.listen((data) {
      if (!mounted) return;
      final session = data['session'] as Map<String, dynamic>?;
      if (session == null) return;
      final authState = context.read<AuthCubit>().state;
      if (session['doctorId'] != authState.user?.effectiveDoctorId) return;
      _syncWithServer();
    });

    ws.sessionEndedStream.listen((data) {
      if (!mounted) return;
      final doctorId = data['doctorId'] as int?;
      final authState = context.read<AuthCubit>().state;
      if (doctorId != authState.user?.effectiveDoctorId) return;
      _syncWithServer();
    });

    ws.reportSavedStream.listen((data) {
      if (!mounted || _isFinalizing) return;
      final report = data['report'] as Map<String, dynamic>?;
      final sessionId = report?['sessionId'] as String?;
      if (sessionId == _activeSessionId && _phase != SessionPhase.none) {
        _snack('Session closed from website - report saved', const Color(0xFF0EA5E9));
        _confirmTimer?.cancel();
        _pollTimer?.cancel();
        _heartbeatTimer?.cancel();
        _resetSession();
      }
    });

    ws.dataChangeStream.listen((data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      final entity = data['entity'] as String?;
      if (type == 'FULL_SYNC' || entity == 'attendance-session') {
        _syncWithServer();
      }
    });
  }

  void _startConfirmTimer() {
    _confirmTimer?.cancel();
    // Ensure sessionEndTime is set; fallback to now if missing
    _sessionEndTime ??= DateTime.now();
    _confirmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _qrDuration - DateTime.now().difference(_sessionEndTime!);
      setState(() => _confirmRemaining = remaining);
      if (remaining.isNegative) {
        timer.cancel();
        _finalizeSession();
      }
    });
  }

  // ============================================
  // Helpers
  // ============================================
  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmtDur(Duration d) {
    if (d.isNegative) return '0:00';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ============================================
  // Restore active session from server on app open
  // ============================================
  Future<void> _tryRestoreSession() async {
    if (_didCheckServer || _phase != SessionPhase.none) return;
    _didCheckServer = true;

    final auth = context.read<AuthCubit>().state;
    if (auth.token == null || auth.user == null) return;

    try {
      final res = await http
          .get(
            Uri.parse(
                '${AppConstants.baseUrl}/api/active-sessions/doctor/${auth.user!.effectiveDoctorId}'),
            headers: _headers(auth.token!),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final sessions = jsonDecode(res.body) as List;
        if (sessions.isNotEmpty) {
          final s = sessions.first;
          // ignore: use_build_context_synchronously
          final ds = context.read<DataCubit>().state;
          Lecture? lecture;
          try {
            lecture = ds.lectures.firstWhere((l) => l.id == s['lectureId']);
          } catch (_) {}

          if (lecture != null && mounted) {
            final students =
                await _getEnrolledStudents(lecture.subjectId, auth.token!);

            // Detect if session is in QR phase (server uses phase='qr' and qrPhaseEndTime)
            final serverPhase = s['phase'] as String?;
            final qrEndTimeStr = s['qrPhaseEndTime'] as String?;
            final qrEndTime = qrEndTimeStr != null ? DateTime.tryParse(qrEndTimeStr) : null;
            final isQrPhase = serverPhase == 'qr' && qrEndTime != null;

            Duration? qrRemaining;
            if (isQrPhase) {
              final rem = qrEndTime.difference(DateTime.now());
              qrRemaining = rem.isNegative ? Duration.zero : rem;
            }

            setState(() {
              _phase = isQrPhase ? SessionPhase.confirming : SessionPhase.active;
              _activeSession = lecture;
              _activeSessionId = s['sessionId'] as String?;
              _sessionStartTime =
                  DateTime.tryParse(s['startTime'] ?? s['createdAt'] ?? '') ??
                      DateTime.now();
              _sessionEndTime = isQrPhase ? qrEndTime : null;
              _sessionStudents = students;
              _isCameraOpen = !isQrPhase;
              _showActiveSessions = true;
              if (isQrPhase) {
                _confirmRemaining = (qrRemaining != null && !qrRemaining.isNegative)
                    ? qrRemaining
                    : _qrDuration;
              }
            });
            if (_activeSessionId != null) {
              _startHeartbeat(_activeSessionId!, auth.token!);
              _startPolling(_activeSessionId!, auth.token!);
              _startContinuousSync();
            }
            if (isQrPhase) _startConfirmTimer();
          }
        }
      }
    } catch (_) {}
  }

  // ============================================
  // Continuous Server Sync (Source of Truth)
  // ============================================
  void _startContinuousSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 8), (_) => _syncWithServer());
  }

  Future<void> _syncWithServer() async {
    if (!mounted || _isActivating || _isFinalizing) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null || auth.user == null) return;

    try {
      final res = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/api/active-sessions/doctor/${auth.user!.effectiveDoctorId}'),
            headers: _headers(auth.token!),
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (res.statusCode != 200) return;

      final sessions = jsonDecode(res.body) as List;

      // ── No session on server ──────────────────────────────────────
      if (sessions.isEmpty) {
        if (_phase != SessionPhase.none) {
          _snack('Session closed from another device', const Color(0xFF0EA5E9));
          _confirmTimer?.cancel();
          _pollTimer?.cancel();
          _heartbeatTimer?.cancel();
          _resetSession();
        }
        return;
      }

      final s = sessions.first as Map<String, dynamic>;
      final serverSessionId = s['sessionId'] as String?;
      final serverPhase = s['phase'] as String?;
      // Server uses phase='qr' and qrPhaseEndTime (not 'qr_mode' / endedAt)
      final qrEndTimeStr = s['qrPhaseEndTime'] as String?;
      final qrEndTime = qrEndTimeStr != null ? DateTime.tryParse(qrEndTimeStr) : null;
      final isQrPhase = serverPhase == 'qr' && qrEndTime != null;

      // ── App has NO session but server has one → restore it ────────
      if (_phase == SessionPhase.none) {
        final ds = context.read<DataCubit>().state;
        Lecture? lecture;
        try {
          lecture = ds.lectures.firstWhere((l) => l.id == s['lectureId']);
        } catch (_) {}
        if (lecture == null) return;

        final students = await _getEnrolledStudents(lecture.subjectId, auth.token!);
        if (!mounted) return;

        Duration qrRemaining = _qrDuration;
        if (isQrPhase) {
          final rem = qrEndTime.difference(DateTime.now());
          if (rem.isNegative) return; // expired — ignore
          qrRemaining = rem;
        }

        setState(() {
          _phase = isQrPhase ? SessionPhase.confirming : SessionPhase.active;
          _activeSession = lecture;
          _activeSessionId = serverSessionId;
          _sessionStartTime = DateTime.tryParse(s['startTime'] ?? s['createdAt'] ?? '') ?? DateTime.now();
          _sessionEndTime = isQrPhase ? qrEndTime : null;
          _sessionStudents = students;
          _isCameraOpen = !isQrPhase;
          _showActiveSessions = true;
          if (isQrPhase) _confirmRemaining = qrRemaining;
        });
        if (_activeSessionId != null) {
          _startHeartbeat(_activeSessionId!, auth.token!);
          _startPolling(_activeSessionId!, auth.token!);
        }
        if (isQrPhase) _startConfirmTimer();
        _snack('Session synced from server', Colors.green);
        return;
      }

      // ── Different session ID → full reset + restore ───────────────
      if (_activeSessionId != serverSessionId) {
        _confirmTimer?.cancel();
        _pollTimer?.cancel();
        _heartbeatTimer?.cancel();
        _resetSession();
        _didCheckServer = false;
        await _tryRestoreSession();
        return;
      }

      // ── Same session, but phase changed to QR ────────────────────
      if (_phase == SessionPhase.active && isQrPhase) {
        final remaining = qrEndTime.difference(DateTime.now());
        setState(() {
          _phase = SessionPhase.confirming;
          _sessionEndTime = qrEndTime;
          _confirmRemaining = remaining.isNegative ? Duration.zero : remaining;
        });
        _startConfirmTimer();
        _snack('QR mode synced from server', Colors.orange);
      }
    } catch (_) {}
  }

  void _resetSession() {
    _syncTimer?.cancel();
    setState(() {
      _phase = SessionPhase.none;
      _activeSession = null;
      _activeSessionId = null;
      _sessionStartTime = null;
      _sessionEndTime = null;
      _sessionStudents = null;
      _isCameraOpen = false;
      _confirmedCount = 0;
      _pendingCount = 0;
      _attendanceRecords = [];
      _showActiveSessions = false;
    });
  }

  // ============================================
  // Get enrolled students for a subject (WITH CACHE)
  // ============================================
  Future<List<Student>> _getEnrolledStudents(
      int subjectId, String token) async {
    // Check cache first
    if (_enrolledStudentsCache.containsKey(subjectId)) {
      final cacheTime = _cacheTimestamp[subjectId];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheDuration) {
        print('📦 Using cached enrolled students for subject $subjectId');
        return _enrolledStudentsCache[subjectId]!;
      }
    }

    try {
      final res = await http
          .get(
            Uri.parse(
                '${AppConstants.baseUrl}/api/subject/$subjectId/enrolled-students'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['students'] as List? ?? [];
        List<Student> students = [];
        if (list.isNotEmpty) {
          students = list.map<Student>((j) => Student.fromJson(j)).toList();
        }

        // Store in cache
        _enrolledStudentsCache[subjectId] = students;
        _cacheTimestamp[subjectId] = DateTime.now();
        print(
            '✅ Cached ${students.length} enrolled students for subject $subjectId');
        return students;
      }
    } catch (e) {
      debugPrint('Error fetching enrolled students: $e');
    }
    return [];
  }

  // ============================================
  // 1. ACTIVATE SESSION with WebSocket Broadcast
  // ============================================
  Future<void> _activateSession(Lecture lecture) async {
    setState(() => _isActivating = true);
    final auth = context.read<AuthCubit>().state;
    final token = auth.token;
    final user = auth.user;

    if (token == null || user == null) {
      _snack('Not authenticated', Colors.red);
      setState(() => _isActivating = false);
      return;
    }

    try {
      final sessionId =
          'SES-${DateTime.now().millisecondsSinceEpoch}-${lecture.id}';
      final now = DateTime.now();

      // Create session on server
      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/active-sessions'),
            headers: _headers(token),
            body: jsonEncode({
              'sessionId': sessionId,
              'lectureId': lecture.id,
              'doctorId': user.effectiveDoctorId,
              'doctorName': user.name,
              'subjectName': lecture.subjectName,
              'level': lecture.level,
              'department': lecture.department,
              'startTime': now.toIso8601String(),
              'deviceInfo': {'source': 'mobile_app'},
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('Activate response: ${res.statusCode} ${res.body}');

      if (res.statusCode != 200) {
        String errMsg = 'Failed (${res.statusCode})';
        try {
          final d = jsonDecode(res.body);
          errMsg = d['error'] ?? d['message'] ?? errMsg;
        } catch (_) {}
        if (!mounted) return;
        _snack(errMsg, Colors.red);
        setState(() => _isActivating = false);
        return;
      }

      // ✅ Broadcast to all clients via WebSocket
      final ws = WebSocketService.instance;
      ws.sendMessage({
        'type': 'SESSION_ACTIVATED',
        'session': {
          'sessionId': sessionId,
          'lectureId': lecture.id,
          'doctorId': user.effectiveDoctorId,
          'doctorName': user.name,
          'subjectName': lecture.subjectName,
          'level': lecture.level,
          'department': lecture.department,
          'startTime': now.toIso8601String(),
        },
        'doctorId': user.effectiveDoctorId,
        'timestamp': DateTime.now().toIso8601String()
      });

      // Open camera on host
      bool camOk = false;
      try {
        final cr = await http
            .post(
              Uri.parse('${AppConstants.baseUrl}/api/camera/request'),
              headers: _headers(token),
              body: jsonEncode({
                'sessionId': sessionId,
                'lectureId': lecture.id,
                'doctorName': user.name,
              }),
            )
            .timeout(const Duration(seconds: 10));
        camOk = jsonDecode(cr.body)['success'] == true;
      } catch (_) {}

      // Get enrolled students (from cache or API)
      final students = await _getEnrolledStudents(lecture.subjectId, token);

      if (!mounted) return;

      setState(() {
        _phase = SessionPhase.active;
        _activeSession = lecture;
        _activeSessionId = sessionId;
        _sessionStartTime = now;
        _sessionEndTime = null;
        _sessionStudents = students;
        _showActiveSessions = true;
        _showStudentList = false;
        _isCameraOpen = camOk;
        _isActivating = false;
        _confirmedCount = 0;
        _pendingCount = 0;
        _attendanceRecords = [];
      });

      _startHeartbeat(sessionId, token);
      _startPolling(sessionId, token);
      _startContinuousSync();
      _snack(
          'Session started: ${lecture.subjectName} (${students.length} students)${camOk ? ' - Camera running' : ''}',
          Colors.green);
    } catch (e) {
      debugPrint('Activate error: $e');
      if (!mounted) return;
      _snack('Connection error: $e', Colors.red);
      setState(() => _isActivating = false);
    }
  }

// ============================================
// 2. END SESSION — enter QR phase + sync to website
// ============================================
  Future<void> _endSession() async {
    if (_activeSessionId == null) return;
    final authState = context.read<AuthCubit>().state;
    if (authState.token == null) return;

    try {
      // Call the correct server endpoint — this sets phase='qr', stores qrPhaseEndTime,
      // and broadcasts DATA_CHANGE active-session qr-phase-started to ALL clients.
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/active-sessions/$_activeSessionId/begin-qr-phase'),
        headers: _headers(authState.token!),
        body: jsonEncode({'durationMinutes': 30}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final qrEndTimeStr = body['qrPhaseEndTime'] as String?;
        final qrEndTime = qrEndTimeStr != null ? DateTime.tryParse(qrEndTimeStr) : null;
        final remaining = qrEndTime != null
            ? qrEndTime.difference(DateTime.now())
            : _qrDuration;

        setState(() {
          _phase = SessionPhase.confirming;
          // ✅ Record the actual end-click moment for the report.
          _lectureEndedAt = DateTime.now();
          _sessionEndTime = qrEndTime ?? DateTime.now();
          _confirmRemaining = remaining.isNegative ? Duration.zero : remaining;
        });
        _startConfirmTimer();
        _snack('Lecture ended - QR confirmation open for 30 min', Colors.orange);
      } else if (res.statusCode == 404) {
        // The server lost track of this session (e.g. it restarted, or another
        // device ended it first). Treat it as already ended and just clean up
        // local state instead of confusing the user with a red "Failed 404".
        setState(() {
          _phase = SessionPhase.none;
          _activeSession = null;
          _activeSessionId = null;
          _sessionStartTime = null;
          _sessionEndTime = null;
          _sessionStudents = null;
          _isCameraOpen = false;
        });
        _snack('Session was already ended on the server', Colors.orange);
      } else {
        _snack('Failed to end session (${res.statusCode})', Colors.red);
      }
    } catch (e) {
      _snack('Connection error ending session', Colors.red);
    }
  }

// ============================================
// 3. FINALIZE — close camera + send report + sync to website
// ============================================
  Future<void> _finalizeSession() async {
    _confirmTimer?.cancel();
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _syncTimer?.cancel();
    _isFinalizing = true;

    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) {
      _isFinalizing = false;
      return;
    }

    // Snapshot session data before we clear state
    final sessionIdSnapshot = _activeSessionId;
    final sessionStudentsSnapshot = List<Student>.from(_sessionStudents ?? []);
    final attendanceSnapshot = List<Map<String, dynamic>>.from(_attendanceRecords);
    final confirmedSnapshot = _confirmedCount;
    final pendingSnapshot = _pendingCount;

    Map<String, dynamic>? report;

    try {
      // Delete session → camera closes + removes from server
      final deleteRes = await http
          .delete(
            Uri.parse(
                '${AppConstants.baseUrl}/api/active-sessions/$sessionIdSnapshot'),
            headers: _headers(auth.token!),
          )
          .timeout(const Duration(seconds: 10));

      print('Delete session response: ${deleteRes.statusCode}');
      if (deleteRes.statusCode != 200 && deleteRes.statusCode != 204) {
        print('⚠️ Session delete returned ${deleteRes.statusCode}: ${deleteRes.body}');
      }

      // Build report using snapshots (safe even if state is cleared mid-flight)
      final rptStudents = sessionStudentsSnapshot.map((s) {
            final rec = attendanceSnapshot
                .cast<Map<String, dynamic>?>()
                .firstWhere(
                    (r) =>
                        r?['student_id'] == s.id ||
                        r?['student_id_number'] == s.studentId,
                    orElse: () => null);

            final faceAt = rec?['face_detected_at'] ?? rec?['created_at'] ?? '';
            final qrAt = rec?['confirmed_at'] ?? rec?['qr_scanned_at'] ?? '';
            String? dur;
            if (faceAt.toString().isNotEmpty && qrAt.toString().isNotEmpty) {
              try {
                final d = DateTime.parse(qrAt).difference(DateTime.parse(faceAt));
                dur = d.inHours > 0
                    ? '${d.inHours}h ${d.inMinutes % 60}m'
                    : '${d.inMinutes}m';
              } catch (_) {}
            }

            return {
              'student_id': s.id,
              'student_id_number': s.studentId,
              'student_name': s.name,
              'status': rec?['status'] ?? 'absent',
              'face_detected_at': faceAt,
              'qr_scanned_at': qrAt,
              'confirmed_by': rec?['confirmed_by'],
              'attendance_duration': dur,
            };
          }).toList();

      final nowIso = DateTime.now().toIso8601String();
      // Real lecture end time = when the user pressed End. Falls back to
      // the QR phase deadline (`_sessionEndTime`) only if for some reason
      // the click time wasn't captured.
      final lectureEndIso = (_lectureEndedAt ?? _sessionEndTime ?? DateTime.now())
          .toIso8601String();
      report = {
        'sessionId': sessionIdSnapshot,
        'lectureId': _activeSession?.id,
        'doctorId': auth.user?.effectiveDoctorId,
        'doctorName': auth.user?.name,
        'subjectName': _activeSession?.subjectName,
        'level': _activeSession?.level,
        'department': _activeSession?.department,
        // Match the field names the website / server use, so the same JSON
        // renders identically on both platforms.
        'startTime': _sessionStartTime?.toIso8601String(),
        'endTime': lectureEndIso,
        'createdAt': nowIso,
        'endedAt': lectureEndIso,
        'totalStudents': sessionStudentsSnapshot.length,
        'presentCount': confirmedSnapshot,
        'pendingCount': pendingSnapshot,
        'absentCount': sessionStudentsSnapshot.length - confirmedSnapshot - pendingSnapshot,
        'students': rptStudents,
      };

      // Send report to server
      final reportRes = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/attendance-reports'),
            headers: _headers(auth.token!),
            body: jsonEncode(report),
          )
          .timeout(const Duration(seconds: 10));

      print('Report save response: ${reportRes.statusCode}');

      if (reportRes.statusCode == 200) {
        // ✅ Broadcast report to all clients
        final ws = WebSocketService.instance;
        ws.sendMessage({
          'type': 'REPORT_SAVED',
          'report': report,
          'timestamp': DateTime.now().toIso8601String()
        });
        print('📡 Broadcasted REPORT_SAVED');
      }
    } catch (e) {
      debugPrint('Finalize error: $e');
    }

    _isFinalizing = false;

    if (mounted) {
      setState(() {
        _phase = SessionPhase.none;
        _activeSession = null;
        _activeSessionId = null;
        _sessionStartTime = null;
        _sessionEndTime = null;
        _sessionStudents = null;
        _isCameraOpen = false;
        _confirmedCount = 0;
        _pendingCount = 0;
        _attendanceRecords = [];
      });

      _snack('Camera closed - Report saved', const Color(0xFF0EA5E9));
    }
  }

  // ============================================
  // Timers
  // ============================================
  void _startHeartbeat(String sid, String token) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        await http.post(
          Uri.parse(
              '${AppConstants.baseUrl}/api/active-sessions/$sid/heartbeat'),
          headers: _headers(token),
        );
      } catch (_) {}
    });
  }

  void _startPolling(String sid, String token) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final res = await http
            .get(
              Uri.parse(
                  '${AppConstants.baseUrl}/api/attendance-session-data/$sid'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 5));

        // Session deleted from another device (website final close)
        if (res.statusCode == 404 && mounted && _phase != SessionPhase.none) {
          _snack('Session closed from another device', const Color(0xFF0EA5E9));
          _confirmTimer?.cancel();
          _pollTimer?.cancel();
          _heartbeatTimer?.cancel();
          _resetSession();
          return;
        }

        if (res.statusCode == 200 && mounted) {
          final data = jsonDecode(res.body);
          final recs =
              (data['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          // Detect QR phase change from website (fallback if WebSocket missed)
          // Server uses phase='qr' and qrPhaseEndTime (not 'qr_mode' / endedAt)
          final sessionPhase = (data['session']?['phase'] ?? data['phase']) as String?;
          final qrEndTimeStr = (data['session']?['qrPhaseEndTime'] ?? data['qrPhaseEndTime']) as String?;
          final qrEndTime = qrEndTimeStr != null ? DateTime.tryParse(qrEndTimeStr) : null;

          if (sessionPhase == 'qr' && _phase == SessionPhase.active && qrEndTime != null) {
            final remaining = qrEndTime.difference(DateTime.now());
            setState(() {
              _phase = SessionPhase.confirming;
              _sessionEndTime = qrEndTime;
              _confirmRemaining = remaining.isNegative ? Duration.zero : remaining;
              _attendanceRecords = recs;
              _confirmedCount = recs.where((r) => r['status'] == 'confirmed').length;
              _pendingCount = recs.where((r) => r['status'] == 'pending').length;
            });
            _startConfirmTimer();
            _snack('QR mode synced from server', Colors.orange);
          } else {
            setState(() {
              _attendanceRecords = recs;
              _confirmedCount =
                  recs.where((r) => r['status'] == 'confirmed').length;
              _pendingCount = recs.where((r) => r['status'] == 'pending').length;
            });
          }
        }
      } catch (_) {}
    });
  }

  // ============================================
  // Camera WebView with Permission Handling
  // ============================================
  Future<void> _openCameraView() async {
    if (_activeSessionId == null) return;

    final camStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (!camStatus.isGranted) {
      _snack('Camera permission denied - go to Settings to allow', Colors.red);
      openAppSettings();
      return;
    }

    // ignore: use_build_context_synchronously
    final auth = context.read<AuthCubit>().state;
    final url = '${AppConstants.baseUrl}/camera.html'
        '?sessionId=$_activeSessionId'
        '&lectureId=${_activeSession?.id ?? ''}'
        '&doctorId=${auth.user?.effectiveDoctorId ?? ''}'
        '&doctorName=${Uri.encodeComponent(auth.user?.name ?? '')}'
        '&token=${auth.token ?? ''}';

    // ignore: use_build_context_synchronously
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          _CameraPage(url: url, title: _activeSession?.subjectName ?? 'Camera'),
    ));
  }

  Future<void> _retryCameraOpen() async {
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null || _activeSessionId == null) return;
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/camera/request'),
            headers: _headers(auth.token!),
            body: jsonEncode({
              'sessionId': _activeSessionId,
              'lectureId': _activeSession?.id,
              'doctorName': auth.user?.name,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (jsonDecode(res.body)['success'] == true) {
        setState(() => _isCameraOpen = true);
        _snack('Camera opened!', Colors.green);
      } else {
        _snack('Host not connected', Colors.red);
      }
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  // ============================================
  // Manual Attendance Confirmation
  // ============================================
  Future<void> _confirmStudent(Student student) async {
    if (_activeSessionId == null) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/active-sessions/$_activeSessionId/manual-attendance'),
        headers: _headers(auth.token!),
        body: jsonEncode({
          'studentId': student.id,
          'studentIdNumber': student.studentId,
          'action': 'confirm',
        }),
      ).timeout(const Duration(seconds: 8));
      _refreshAttendanceNow();
    } catch (e) {
      _snack('Error confirming student', Colors.red);
    }
  }

  Future<void> _rejectStudent(Student student) async {
    if (_activeSessionId == null) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/active-sessions/$_activeSessionId/manual-attendance'),
        headers: _headers(auth.token!),
        body: jsonEncode({
          'studentId': student.id,
          'studentIdNumber': student.studentId,
          'action': 'reject',
        }),
      ).timeout(const Duration(seconds: 8));
      _refreshAttendanceNow();
    } catch (e) {
      _snack('Error rejecting student', Colors.red);
    }
  }

  Future<void> _confirmAllPending() async {
    if (_activeSessionId == null) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/active-sessions/$_activeSessionId/confirm-all-pending'),
        headers: _headers(auth.token!),
      ).timeout(const Duration(seconds: 8));
      _snack('All pending confirmed', Colors.green);
      _refreshAttendanceNow();
    } catch (e) {
      _snack('Error confirming all', Colors.red);
    }
  }

  Future<void> _rejectAllPending() async {
    if (_activeSessionId == null) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/active-sessions/$_activeSessionId/reject-all-pending'),
        headers: _headers(auth.token!),
      ).timeout(const Duration(seconds: 8));
      _snack('All pending rejected', Colors.red);
      _refreshAttendanceNow();
    } catch (e) {
      _snack('Error rejecting all', Colors.red);
    }
  }

  Future<void> _refreshAttendanceNow() async {
    if (_activeSessionId == null) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/attendance-session-data/$_activeSessionId'),
        headers: _headers(auth.token!),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final recs = (data['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _attendanceRecords = recs;
          _confirmedCount = recs.where((r) => r['status'] == 'confirmed').length;
          _pendingCount = recs.where((r) => r['status'] == 'pending').length;
        });
      }
    } catch (_) {}
  }

  // ============================================
  // Dialogs
  // ============================================
  void _showActivateConfirmDialog(Lecture lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.play_circle, color: Colors.green, size: 28),
          SizedBox(width: 12),
          Text('Start Lecture', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start "${lecture.subjectName}"?'),
            const SizedBox(height: 12),
            _dialogRow(Icons.videocam, 'Camera starts on host'),
            _dialogRow(Icons.people, 'Only enrolled students'),
            _dialogRow(Icons.qr_code, '30 min QR after lecture'),
            _dialogRow(Icons.analytics, 'Auto report on close'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _activateSession(lecture);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _showEndSessionConfirmDialog(Lecture lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.stop_circle, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('End Lecture', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('End "${lecture.subjectName}"?'),
            const SizedBox(height: 8),
            Text('$_confirmedCount confirmed, $_pendingCount pending',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Flexible(
                    child: Text('Camera stays 30 min for QR',
                        style: TextStyle(fontSize: 11, color: Colors.orange))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _endSession();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('End Lecture'),
          ),
        ],
      ),
    );
  }

  void _showForceFinalize() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.red, size: 28),
          SizedBox(width: 12),
          Text('Close Now?', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
            'Camera will close and report sent now. Students without QR stay as Pending.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Wait')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finalizeSession();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Close & Send'),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: Theme.of(context).hintColor),
        const SizedBox(width: 8),
        Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor))),
      ]),
    );
  }

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final currentSemester = dataState.currentSemester;

    final user = authState.user;
    final doctorId = user?.effectiveDoctorId ?? 0;

    // جلب المواد الخاصة بالدكتور في الترم الحالي فقط
    List<Subject> doctorSubjects = dataState.subjects
        .where((s) => s.doctorId == doctorId && s.semester == currentSemester)
        .toList();

    final doctorSubjectIds = doctorSubjects.map((s) => s.id).toList();

    // جلب المحاضرات المرتبطة بهذه المواد فقط
    List<Lecture> doctorLectures = dataState.lectures
        .where((l) => doctorSubjectIds.contains(l.subjectId))
        .toList();

    if (_selectedLevel != 0) {
      doctorLectures =
          doctorLectures.where((l) => l.level == _selectedLevel).toList();
    }
    if (_selectedDay.isNotEmpty) {
      doctorLectures =
          doctorLectures.where((l) => l.day == _selectedDay).toList();
    }

    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    final Map<String, List<Lecture>> lecturesByDay = {};
    for (final day in daysToShow) {
      lecturesByDay[day] = doctorLectures.where((l) => l.day == day).toList()
        ..sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: Column(
          children: [
            // Tab bar
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                children: [
                  _buildTab('Lectures', Icons.calendar_today_rounded,
                      !_showActiveSessions, () {
                    setState(() => _showActiveSessions = false);
                  }),
                  Builder(builder: (ctx) {
                    final user = ctx.watch<AuthCubit>().state.user;
                    final liveLocked = user != null &&
                        !user.hasTAPermission('ta.nav.attendance');
                    return _buildTab(
                      _phase == SessionPhase.confirming ? 'QR Mode' : 'Live',
                      _phase == SessionPhase.confirming
                          ? Icons.qr_code
                          : Icons.qr_code_scanner_rounded,
                      _showActiveSessions && !liveLocked,
                      () {
                        if (liveLocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.lock_outline,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                        'Active Sessions are locked by your professor'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                          return;
                        }
                        setState(() => _showActiveSessions = true);
                      },
                      locked: liveLocked,
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: _showActiveSessions
                  ? _buildActiveSessionsContent()
                  : _buildLecturesContent(lecturesByDay, daysToShow),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
      String label, IconData icon, bool isActive, VoidCallback onTap,
      {bool locked = false}) {
    final inactiveColor =
        _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
    final fgColor = locked
        ? Colors.grey
        : (isActive ? Colors.white : inactiveColor);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: locked
                ? Colors.grey.withValues(alpha: 0.15)
                : (isActive
                    ? Theme.of(context).primaryColor
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(36),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: fgColor)),
              if (locked) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // Lectures Tab
  // ============================================
  Widget _buildLecturesContent(
      Map<String, List<Lecture>> lecturesByDay, List<String> daysToShow) {
    final currentSemester = context.read<DataCubit>().state.currentSemester;

    return CustomScrollView(
      slivers: [
        // ✅ Semester info banner
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Showing lectures for Semester $currentSemester',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Filters (Level only - no semester filter)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildDropdown<int>(
                  _selectedLevel,
                  [
                    const DropdownMenuItem(value: 0, child: Text('All Levels')),
                    ..._levels.map((l) =>
                        DropdownMenuItem(value: l, child: Text('Level $l'))),
                  ],
                  (v) => setState(() => _selectedLevel = v ?? 0),
                ),
                const SizedBox(height: 10),
                _buildDropdown<String?>(
                  _selectedDay.isEmpty ? null : _selectedDay,
                  [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All Days')),
                    ..._days.map((d) =>
                        DropdownMenuItem<String?>(value: d, child: Text(d))),
                  ],
                  (v) => setState(() => _selectedDay = v ?? ''),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, dayIndex) {
              final day = daysToShow[dayIndex];
              final dayLectures = lecturesByDay[day] ?? [];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                    const Color(0xFF0284C7).withValues(alpha: 0.04),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                      left: BorderSide(
                          color: Theme.of(context).primaryColor, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(day,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('${dayLectures.length}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF0EA5E9))),
                          ),
                        ],
                      ),
                    ),
                    ...dayLectures.map((lecture) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: _buildLectureCard(lecture),
                        )),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
            childCount: daysToShow.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildLectureCard(Lecture lecture) {
    final isActive = _activeSession?.id == lecture.id;
    final busy = _phase != SessionPhase.none && !isActive;
    final phaseColor =
        _phase == SessionPhase.confirming ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: phaseColor, width: 1) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? phaseColor : Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.subjectName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color:
                            _isDark ? Colors.white : const Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 2),
                  Text(lecture.timeDisplay,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                  const SizedBox(width: 10),
                  const Icon(Icons.location_on,
                      size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 2),
                  Text(lecture.locationName,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                ]),
                Text(
                    'Level ${lecture.level} - ${lecture.department ?? 'General'}',
                    style:
                        const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Builder(builder: (ctx) {
            final user = ctx.watch<AuthCubit>().state.user;
            final canStart =
                user == null || user.hasTAPermission('ta.attendance.start');
            final canEnd =
                user == null || user.hasTAPermission('ta.attendance.end');
            final permLocked = isActive ? !canEnd : !canStart;
            if (permLocked) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Locked',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                  ],
                ),
              );
            }
            return ElevatedButton(
              onPressed: isActive
                  ? (_phase == SessionPhase.active
                      ? () => _showEndSessionConfirmDialog(lecture)
                      : null)
                  : (busy || _isActivating
                      ? null
                      : () => _showActivateConfirmDialog(lecture)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive
                    ? (_phase == SessionPhase.confirming
                        ? Colors.orange
                        : Colors.red)
                    : (busy ? Colors.grey : Colors.green),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _isActivating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      isActive
                          ? (_phase == SessionPhase.confirming ? 'QR...' : 'End')
                          : (busy ? 'Busy' : 'Activate'),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
            );
          }),
        ],
      ),
    );
  }

  // ============================================
  // Live / QR Mode Tab
  // ============================================
  Widget _buildActiveSessionsContent() {
    if (_phase == SessionPhase.none) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner,
                size: 80,
                color:
                    _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No active sessions',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _isDark
                        ? const Color(0xFF94A3B8)
                        : Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Activate a lecture to start attendance',
                style: TextStyle(
                    fontSize: 13,
                    color: _isDark
                        ? const Color(0xFF64748B)
                        : Colors.grey.shade500)),
          ],
        ),
      );
    }

    final totalStudents = _sessionStudents?.length ?? 0;
    final absentCount = totalStudents - _confirmedCount - _pendingCount;
    final isConfirming = _phase == SessionPhase.confirming;
    final phaseColor = isConfirming ? Colors.orange : const Color(0xFF0EA5E9);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                phaseColor.withValues(alpha: 0.15),
                phaseColor.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: phaseColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(_activeSession!.subjectName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: phaseColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: phaseColor.withValues(alpha: 0.4))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: phaseColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(isConfirming ? 'QR MODE' : 'LIVE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: phaseColor)),
                    ]),
                  ),
                ]),
                if (isConfirming) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.timer, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text('Camera closes in ${_fmtDur(_confirmRemaining)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange)),
                    ]),
                  ),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(_activeSession!.timeDisplay,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8))),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on,
                      size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(_activeSession!.locationName,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  _buildStat(totalStudents.toString(), 'Total', Colors.white),
                  _buildStat(
                      '$_confirmedCount', 'Confirmed', const Color(0xFF10B981)),
                  _buildStat(
                      '$_pendingCount', 'Pending', const Color(0xFFF59E0B)),
                  _buildStat('$absentCount', 'Absent', const Color(0xFFEF4444)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCameraOpen ? _openCameraView : _retryCameraOpen,
              icon: Icon(_isCameraOpen ? Icons.videocam : Icons.videocam_off,
                  size: 20),
              label: Text(_isCameraOpen
                  ? 'View Camera'
                  : 'Camera Offline - Tap to Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isCameraOpen ? const Color(0xFF10B981) : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showStudentList = !_showStudentList),
              icon: Icon(
                  _showStudentList ? Icons.visibility_off : Icons.visibility,
                  size: 18),
              label: Text(_showStudentList
                  ? 'Hide Students'
                  : 'View Students ($totalStudents)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                side: const BorderSide(color: Color(0xFF0EA5E9)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_showStudentList &&
              _sessionStudents != null &&
              _sessionStudents!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12)),
                    ),
                    child: const Row(children: [
                      Expanded(
                          flex: 2,
                          child: Text('ID',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0EA5E9)))),
                      Expanded(
                          flex: 3,
                          child: Text('NAME',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0EA5E9)))),
                      SizedBox(
                          width: 60,
                          child: Text('STATUS',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0EA5E9)),
                              textAlign: TextAlign.center)),
                      SizedBox(
                          width: 68,
                          child: Text('ACTIONS',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0EA5E9)),
                              textAlign: TextAlign.center)),
                    ]),
                  ),
                  ..._sessionStudents!.map((student) {
                    final rec = _attendanceRecords
                        .cast<Map<String, dynamic>?>()
                        .firstWhere(
                            (r) =>
                                r?['student_id'] == student.id ||
                                r?['student_id_number'] == student.studentId,
                            orElse: () => null);
                    final status = rec?['status'] ?? 'absent';
                    final statusColor = status == 'confirmed'
                        ? const Color(0xFF10B981)
                        : status == 'pending'
                            ? const Color(0xFFF59E0B)
                            : Colors.red;
                    final statusLabel = status == 'confirmed'
                        ? 'Present'
                        : status == 'pending'
                            ? 'Pending'
                            : 'Absent';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: _isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade200)),
                      ),
                      child: Row(children: [
                        Expanded(
                            flex: 2,
                            child: Text(student.studentId,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: Color(0xFF0EA5E9)))),
                        Expanded(
                            flex: 3,
                            child: Text(student.name,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B)))),
                        SizedBox(
                          width: 60,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor),
                                textAlign: TextAlign.center),
                          ),
                        ),
                        SizedBox(
                          width: 68,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (status != 'confirmed')
                                GestureDetector(
                                  onTap: () => _confirmStudent(student),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.check,
                                        size: 16, color: Color(0xFF10B981)),
                                  ),
                                ),
                              if (status != 'confirmed') const SizedBox(width: 4),
                              if (status != 'absent')
                                GestureDetector(
                                  onTap: () => _rejectStudent(student),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                    );
                  }),
                  // Bulk action buttons
                  if (_pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _confirmAllPending,
                            icon: const Icon(Icons.check_circle_outline, size: 14),
                            label: const Text('Confirm All Pending',
                                style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _rejectAllPending,
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Reject All Pending',
                                style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_phase == SessionPhase.active)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showEndSessionConfirmDialog(_activeSession!),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('End Lecture (Start QR)',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            )
          else if (_phase == SessionPhase.confirming)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _showForceFinalize,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('Close Now & Send Report',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ]),
    );
  }

  Widget _buildDropdown<T>(
      T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(
              color: _isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ============================================
// Camera Page — InAppWebView (supports self-signed SSL)
// ============================================
class _CameraPage extends StatefulWidget {
  final String url;
  final String title;
  const _CameraPage({required this.url, required this.title});
  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> {
  bool _loading = true;
  String? _error;
  InAppWebViewController? _ctrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _ctrl?.reload();
            },
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text('Failed to load camera',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _ctrl?.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ))
          : Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                  ),
                  onWebViewCreated: (c) => _ctrl = c,
                  onLoadStart: (_, __) {
                    if (mounted) {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                    }
                  },
                  onLoadStop: (_, __) {
                    if (mounted) setState(() => _loading = false);
                  },
                  // ignore: deprecated_member_use
                  onLoadError: (_, __, ___, msg) {
                    if (mounted) {
                      setState(() {
                        _loading = false;
                        _error = msg;
                      });
                    }
                  },
                  onReceivedServerTrustAuthRequest: (_, challenge) async {
                    return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED);
                  },
                  onPermissionRequest: (_, request) async {
                    return PermissionResponse(
                        resources: request.resources,
                        action: PermissionResponseAction.GRANT);
                  },
                ),
                if (_loading)
                  const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF10B981))),
              ],
            ),
    );
  }
}
