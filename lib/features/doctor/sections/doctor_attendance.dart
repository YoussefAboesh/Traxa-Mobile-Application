import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/lecture.dart';
import '../../../models/student.dart';
import '../../../models/section.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/app_skeleton.dart';
import '../../../core/logger.dart';

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

  String _selectedDay = '';
  bool _showActiveSessions = false;
  int _selectedLevel = 0;

  SessionPhase _phase = SessionPhase.none;
  Lecture? _activeSession;
  String? _activeSessionId;
  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;
  DateTime? _lectureEndedAt;
  List<Student>? _sessionStudents;
  bool _showStudentList = false;
  bool _isActivating = false;
  bool _isFinalizing = false;

  List<Map<String, dynamic>> _attendanceRecords = [];
  int _confirmedCount = 0;
  int _pendingCount = 0;

  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  Timer? _confirmTimer;
  Timer? _syncTimer;
  Duration _confirmRemaining = Duration.zero;

  bool _didCheckServer = false;

  DateTime? _lastLocalEdit;

  Map<String, dynamic> _taSubjectPerms = {};

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

  final AttendanceRepository _attendanceRepo = getIt<AttendanceRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithServer();
      _loadTaPermissions();
    });
    _setupWebSocketListeners();
    _startContinuousSync();
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
    logDebug('🗑️ Enrolled students cache cleared');
  }

  // ============================================
  // Refresh Data (Pull-to-Refresh)
  // ============================================
  Future<void> _refreshData() async {
    if (_isActivating) return;
    _clearEnrolledStudentsCache();
    setState(() => _didCheckServer = false);
    await _tryRestoreSession();
    await _loadTaPermissions();
    // ignore: use_build_context_synchronously
    await context.read<DataCubit>().loadAllData();
  }

  // ============================================
  // WebSocket Listeners for Real-time Sync
  // ============================================
  void _setupWebSocketListeners() {
    final ws = WebSocketService.instance;

    ws.sessionActivatedStream.listen((data) {
      if (!mounted) return;
      final session = data['session'] as Map<String, dynamic>?;
      if (session == null) return;
      final authState = context.read<AuthCubit>().state;
      if (session['doctorId'] != _ownerId(authState.user)) return;
      _syncWithServer();
    });

    ws.sessionEndedStream.listen((data) {
      if (!mounted) return;
      final doctorId = data['doctorId'] as int?;
      final authState = context.read<AuthCubit>().state;
      if (doctorId != _ownerId(authState.user)) return;
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
      final action = data['action'] as String?;
      if (type == 'FULL_SYNC' || entity == 'attendance-session') {
        _syncWithServer();
      }
      if (entity == 'active-session') {
        if (action == 'attendance-updated') {
          _refreshAttendanceNow();
        } else {
          _syncWithServer();
        }
      }
      if (entity == 'ta-subject-permission') {
        _applyTaPermissionChange(data['data']);
      } else if (type == 'FULL_SYNC' || entity == 'subject') {
        _loadTaPermissions();
      }
    });
  }

  void _startConfirmTimer() {
    _confirmTimer?.cancel();
    _sessionEndTime ??= DateTime.now().add(_qrDuration);
    _confirmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _sessionEndTime!.difference(DateTime.now());
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
    ));
  }

  String _fmtDur(Duration d) {
    if (d.isNegative) return '0:00';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _fmtClock(dynamic iso) {
    final s = iso?.toString() ?? '';
    if (s.isEmpty) return '';
    final dt = DateTime.tryParse(s)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$h:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _clockString(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour > 12 ? l.hour - 12 : (l.hour == 0 ? 12 : l.hour);
    final m = l.minute.toString().padLeft(2, '0');
    final s = l.second.toString().padLeft(2, '0');
    return '$h:$m:$s ${l.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ── TA / Section support ──────────────────────────────────────────────
  // A TA works on "sections" instead of "lectures", with the same session flow.
  bool get _isTA =>
      context.read<AuthCubit>().state.user?.isTeachingAssistant ?? false;

  String get _term => _isTA ? 'Section' : 'Lecture';

  int _ownerId(dynamic user) {
    if (user == null) return 0;
    return user.isTeachingAssistant
        ? (user.id as int)
        : (user.effectiveDoctorId as int);
  }

  Lecture _sectionToLecture(Section s) => Lecture(
        id: s.id,
        subjectId: s.subjectId,
        subjectName: s.subjectName,
        doctorId: 0,
        doctorName: s.taName,
        level: s.level,
        department: s.department,
        day: s.day,
        timeslotId: 0,
        timeDisplay: s.timeDisplay,
        locationId: 0,
        locationName: s.locationName,
        active: true,
      );

  Lecture? _resolveActivatable(int id, dynamic ds, bool isTA) {
    if (isTA) {
      for (final s in ds.allSections) {
        if (s.id == id) return _sectionToLecture(s);
      }
      return null;
    }
    for (final l in ds.lectures) {
      if (l.id == id) return l;
    }
    return null;
  }

  Future<void> _loadTaPermissions() async {
    if (!mounted) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null || !(auth.user?.isTeachingAssistant ?? false)) {
      return;
    }
    try {
      final res = await http
          .get(
            Uri.parse(
                '${AppConstants.baseUrl}/api/ta-subject-permissions/my-permissions'),
            headers: _headers(auth.token!),
          )
          .timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final perms = data['permissions'];
      if (perms is Map) {
        setState(() => _taSubjectPerms = Map<String, dynamic>.from(perms));
      }
    } catch (_) {}
  }

  void _applyTaPermissionChange(dynamic payload) {
    if (!mounted) return;
    final user = context.read<AuthCubit>().state.user;
    if (user == null || !user.isTeachingAssistant) return;

    if (payload is Map) {
      final taId = payload['taId'];
      if (taId != null && taId != user.id) return;

      final subjectId = payload['subjectId'];
      final perms = payload['permissions'];
      if (subjectId != null && perms is Map) {
        setState(() {
          _taSubjectPerms = {
            ..._taSubjectPerms,
            '$subjectId': Map<String, dynamic>.from(perms),
          };
        });
        return;
      }
    }
    _loadTaPermissions();
  }

  bool _canActivateSubject(int subjectId, dynamic user) {
    if (user == null || !(user.isTeachingAssistant as bool)) return true;
    final live = _taSubjectPerms['$subjectId'];
    if (live is Map) return live['ta.session.activate'] != false;
    return user.canActivateSessionForSubject(subjectId) as bool;
  }

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
                '${AppConstants.baseUrl}/api/active-sessions/doctor/${_ownerId(auth.user)}'),
            headers: _headers(auth.token!),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final sessions = jsonDecode(res.body) as List;
        if (sessions.isNotEmpty) {
          final s = sessions.first;
          // ignore: use_build_context_synchronously
          final ds = context.read<DataCubit>().state;
          final isTA = auth.user?.isTeachingAssistant ?? false;
          final lecture =
              _resolveActivatable(s['lectureId'] as int? ?? -1, ds, isTA);

          if (lecture != null && mounted) {
            final students =
                await _getEnrolledStudents(lecture.subjectId, auth.token!);

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
              _lectureEndedAt = isQrPhase
                  ? (DateTime.tryParse(s['qrPhaseStartTime'] ?? '') ?? qrEndTime)
                  : null;
              _sessionStudents = students;
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
            Uri.parse('${AppConstants.baseUrl}/api/active-sessions/doctor/${_ownerId(auth.user)}'),
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
      final qrEndTimeStr = s['qrPhaseEndTime'] as String?;
      final qrEndTime = qrEndTimeStr != null ? DateTime.tryParse(qrEndTimeStr) : null;
      final isQrPhase = serverPhase == 'qr' && qrEndTime != null;

      // ── App has NO session but server has one → restore it ────────
      if (_phase == SessionPhase.none) {
        final ds = context.read<DataCubit>().state;
        final isTA = auth.user?.isTeachingAssistant ?? false;
        final lecture =
            _resolveActivatable(s['lectureId'] as int? ?? -1, ds, isTA);
        if (lecture == null) return;

        final students = await _getEnrolledStudents(lecture.subjectId, auth.token!);
        if (!mounted) return;

        Duration qrRemaining = _qrDuration;
        if (isQrPhase) {
          final rem = qrEndTime.difference(DateTime.now());
          if (rem.isNegative) return;
          qrRemaining = rem;
        }

        setState(() {
          _phase = isQrPhase ? SessionPhase.confirming : SessionPhase.active;
          _activeSession = lecture;
          _activeSessionId = serverSessionId;
          _sessionStartTime = DateTime.tryParse(s['startTime'] ?? s['createdAt'] ?? '') ?? DateTime.now();
          _sessionEndTime = isQrPhase ? qrEndTime : null;
          _lectureEndedAt = isQrPhase
              ? (DateTime.tryParse(s['qrPhaseStartTime'] ?? '') ?? qrEndTime)
              : null;
          _sessionStudents = students;
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
          _lectureEndedAt ??=
              DateTime.tryParse(s['qrPhaseStartTime'] ?? '') ?? DateTime.now();
          _confirmRemaining = remaining.isNegative ? Duration.zero : remaining;
        });
        _startConfirmTimer();
        _snack('QR mode synced from server', Colors.orange);
      }
    } catch (_) {}
  }

  void _resetSession() {
    setState(() {
      _phase = SessionPhase.none;
      _activeSession = null;
      _activeSessionId = null;
      _sessionStartTime = null;
      _sessionEndTime = null;
      _lectureEndedAt = null;
      _sessionStudents = null;
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
    if (_enrolledStudentsCache.containsKey(subjectId)) {
      final cacheTime = _cacheTimestamp[subjectId];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheDuration) {
        logDebug('📦 Using cached enrolled students for subject $subjectId');
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

        _enrolledStudentsCache[subjectId] = students;
        _cacheTimestamp[subjectId] = DateTime.now();
        logDebug(
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
    final auth = context.read<AuthCubit>().state;
    if (!_canActivateSubject(lecture.subjectId, auth.user)) {
      _snack('Session activation is locked for this subject by your professor',
          Colors.orange);
      return;
    }
    setState(() => _isActivating = true);
    final token = auth.token;
    final user = auth.user;

    if (token == null || user == null) {
      _snack('Not authenticated', Colors.red);
      setState(() => _isActivating = false);
      return;
    }

    try {
      final students = await _getEnrolledStudents(lecture.subjectId, token);
      if (!mounted) return;
      if (students.isEmpty) {
        _snack(
            'No students are registered for this ${_term.toLowerCase()} yet',
            Colors.orange);
        setState(() => _isActivating = false);
        return;
      }

      final sessionId =
          'SES-${DateTime.now().millisecondsSinceEpoch}-${lecture.id}';
      final now = DateTime.now();

      // 1) Create the active session first so the camera page has something
      //    to attach to when it loads.
      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/active-sessions'),
            headers: _headers(token),
            body: jsonEncode({
              'sessionId': sessionId,
              'lectureId': lecture.id,
              'doctorId': _ownerId(user),
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

      // 2) Ask the host page to open the camera. Server's success flag is
      //    unreliable on this build, so we don't gate on it.
      await _attendanceRepo.requestCameraHost(
        token: token,
        sessionId: sessionId,
        lectureId: lecture.id,
        doctorName: user.name,
      );
      if (!mounted) return;

      // 3) Verify the camera actually came online. The camera page POSTs
      //    /api/attendance-sessions/:sessionId on startup, so a 200 here
      //    proves it's running. If it never shows up within the timeout,
      //    the host page is closed or the popup was blocked → rollback.
      //
      // We show a non-dismissible dialog while polling. The face-api models
      // pull from GitHub's CDN and routinely take 30-60 s on campus Wi-Fi,
      // so the user needs to see that we're still waiting on purpose.
      final progress = ValueNotifier<int>(0);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF0EA5E9)),
              SizedBox(height: 20.h),
              Text('Waiting for camera to start…',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 8.h),
              ValueListenableBuilder<int>(
                valueListenable: progress,
                builder: (_, secs, __) => Text(
                  '$secs s • face-recognition models loading',
                  style: TextStyle(
                      color: const Color(0xFF94A3B8), fontSize: 12.sp),
                ),
              ),
            ],
          ),
        ),
      );

      final cameraStarted = await _attendanceRepo.waitForCameraStarted(
        sessionId: sessionId,
        token: token,
        onTick: (elapsed) => progress.value = elapsed.inSeconds,
      );

      progress.dispose();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      if (!cameraStarted) {
        // Rollback: kill the active session we just created so it doesn't
        // sit there orphaned with nobody watching.
        await _attendanceRepo.deleteSession(
          sessionId: sessionId,
          token: token,
        );
        if (!mounted) return;
        _snack(
            'Camera did not open within 90 s. Open the host page (host_listener.html) on the server, allow popups for it, and try again.',
            Colors.red);
        setState(() => _isActivating = false);
        return;
      }

      final ws = WebSocketService.instance;
      ws.sendMessage({
        'type': 'SESSION_ACTIVATED',
        'session': {
          'sessionId': sessionId,
          'lectureId': lecture.id,
          'doctorId': _ownerId(user),
          'doctorName': user.name,
          'subjectName': lecture.subjectName,
          'level': lecture.level,
          'department': lecture.department,
          'startTime': now.toIso8601String(),
        },
        'doctorId': _ownerId(user),
        'timestamp': DateTime.now().toIso8601String()
      });

      if (!mounted) return;

      setState(() {
        _phase = SessionPhase.active;
        _activeSession = lecture;
        _activeSessionId = sessionId;
        _sessionStartTime = now;
        _sessionEndTime = null;
        _lectureEndedAt = null;
        _sessionStudents = students;
        _showActiveSessions = true;
        _showStudentList = false;
        _isActivating = false;
        _confirmedCount = 0;
        _pendingCount = 0;
        _attendanceRecords = [];
      });

      _startHeartbeat(sessionId, token);
      _startPolling(sessionId, token);
      _startContinuousSync();
      _snack(
          'Session started: ${lecture.subjectName} (${students.length} students) - Camera running',
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

    final result = await _attendanceRepo.beginQrPhase(
      sessionId: _activeSessionId!,
      token: authState.token!,
      durationMinutes: 30,
    );
    if (!mounted) return;
    result.when(
      success: (body) {
        final qrEndTimeStr = body['qrPhaseEndTime'] as String?;
        final qrEndTime =
            qrEndTimeStr != null ? DateTime.tryParse(qrEndTimeStr) : null;
        final remaining = qrEndTime != null
            ? qrEndTime.difference(DateTime.now())
            : _qrDuration;
        setState(() {
          _phase = SessionPhase.confirming;
          _lectureEndedAt = DateTime.now();
          _sessionEndTime = qrEndTime ?? DateTime.now();
          _confirmRemaining =
              remaining.isNegative ? Duration.zero : remaining;
        });
        _startConfirmTimer();
        _snack('Lecture ended - QR confirmation open for 30 min',
            Colors.orange);
      },
      failure: (e) {
        if (e is ServerException && e.statusCode == 404) {
          setState(() {
            _phase = SessionPhase.none;
            _activeSession = null;
            _activeSessionId = null;
            _sessionStartTime = null;
            _sessionEndTime = null;
            _sessionStudents = null;
          });
          _snack('Session was already ended on the server', Colors.orange);
        } else {
          _snack('Failed to end session', Colors.red);
        }
      },
    );
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

    final sessionIdSnapshot = _activeSessionId;
    var sessionStudentsSnapshot = List<Student>.from(_sessionStudents ?? []);
    var attendanceSnapshot = List<Map<String, dynamic>>.from(_attendanceRecords);

    Map<String, dynamic>? report;

    try {
      final deleteResult = await _attendanceRepo.deleteSession(
        sessionId: sessionIdSnapshot!,
        token: auth.token!,
      );
      final deleteStatus = deleteResult.valueOrNull ?? 0;
      logDebug('Delete session response: $deleteStatus');

      // ── Already closed elsewhere (website / another device) ───────────
      // That device already saved the report — don't send a duplicate
      // (which, with stale state, comes out empty / "unknown" students).
      if (deleteStatus == 404) {
        logDebug('Session already closed elsewhere — skipping duplicate report');
        _isFinalizing = false;
        if (mounted) {
          _resetSession();
          _snack('Session closed', const Color(0xFF0EA5E9));
          _startContinuousSync();
        }
        return;
      }
      if (deleteStatus != 200 && deleteStatus != 204) {
        logDebug('⚠️ Session delete returned $deleteStatus');
      }

      if (sessionStudentsSnapshot.isEmpty && _activeSession != null) {
        sessionStudentsSnapshot =
            await _getEnrolledStudents(_activeSession!.subjectId, auth.token!);
      }

      final freshResult = await _attendanceRepo.getSessionData(
        sessionId: sessionIdSnapshot,
        token: auth.token!,
        timeout: const Duration(seconds: 6),
      );
      freshResult.when(
        success: (freshData) {
          final freshRecs = (freshData['records'] as List?)
              ?.cast<Map<String, dynamic>>();
          if (freshRecs != null && freshRecs.isNotEmpty) {
            attendanceSnapshot = freshRecs;
          }
        },
        failure: (_) {},
      );

      final rptStudents = sessionStudentsSnapshot.map((s) {
            final rec = attendanceSnapshot
                .cast<Map<String, dynamic>?>()
                .firstWhere(
                    (r) =>
                        r?['student_id'] == s.id ||
                        r?['studentId'] == s.id ||
                        r?['student_id_number'] == s.studentId,
                    orElse: () => null);

            final faceAt = (rec?['face_detected_at'] ?? '').toString();
            final didQr = rec?['confirmedByQR'] == true ||
                (rec?['qr_scanned_at']?.toString().isNotEmpty ?? false);
            final qrAt = didQr
                ? (rec?['qr_scanned_at'] ?? rec?['confirmed_at'] ?? '')
                    .toString()
                : '';
            String? dur;
            if (faceAt.isNotEmpty && qrAt.isNotEmpty) {
              try {
                final d = DateTime.parse(qrAt).difference(DateTime.parse(faceAt));
                dur = d.inHours > 0
                    ? '${d.inHours}h ${d.inMinutes % 60}m'
                    : '${d.inMinutes}m';
              } catch (_) {}
            }

            return {
              'student_id': s.studentId,
              'studentId': s.studentId,
              'student_id_number': s.studentId,
              'studentIdNumber': s.studentId,
              'id': s.id,
              'studentDbId': s.id,
              'student_name': s.name,
              'studentName': s.name,
              'name': s.name,
              'status': rec?['status'] ?? 'absent',
              'face_detected_at': faceAt,
              'qr_scanned_at': qrAt,
              'confirmedByQR': didQr,
              'confirmed_by': rec?['confirmed_by'],
              'attendance_duration': dur,
            };
          }).toList();

      // ── Counts: derived from the SAME student list that goes into the
      // report, so the numbers and the rows can never disagree. ───────────
      final confirmedSnapshot =
          rptStudents.where((s) => s['status'] == 'confirmed').length;
      final pendingSnapshot =
          rptStudents.where((s) => s['status'] == 'pending').length;
      final absentCnt = rptStudents.length - confirmedSnapshot - pendingSnapshot;
      final ratePct = rptStudents.isEmpty
          ? 0
          : (confirmedSnapshot / rptStudents.length * 100).round();

      final nowIso = DateTime.now().toIso8601String();
      final lectureEndDt = _lectureEndedAt ?? _sessionEndTime ?? DateTime.now();
      final lectureEndIso = lectureEndDt.toIso8601String();
      final startDt = _sessionStartTime ?? DateTime.now();
      final dateOnly =
          '${startDt.year}-${startDt.month.toString().padLeft(2, '0')}-${startDt.day.toString().padLeft(2, '0')}';
      final startClock = _clockString(startDt);
      final endClock = _clockString(lectureEndDt);
      report = {
        'sessionId': sessionIdSnapshot,
        'lectureId': _activeSession?.id,
        'doctorId': _ownerId(auth.user),
        'doctorName': auth.user?.name,
        'subjectName': _activeSession?.subjectName,
        'subject': _activeSession?.subjectName,
        'level': _activeSession?.level,
        'department': _activeSession?.department,
        'startTime': startClock,
        'endTime': endClock,
        'startTimeIso': _sessionStartTime?.toIso8601String(),
        'endTimeIso': lectureEndIso,
        'createdAt': nowIso,
        'endedAt': lectureEndIso,
        // ── Website section-report table columns ──────────────────────
        'date': dateOnly,
        'time': startClock,
        // ── Counts: send every alias both platforms might read ────────
        'totalStudents': rptStudents.length,
        'total_students': rptStudents.length,
        'enrolled': rptStudents.length,
        'enrolled_count': rptStudents.length,
        'presentCount': confirmedSnapshot,
        'present_count': confirmedSnapshot,
        'present': confirmedSnapshot,
        'confirmed': confirmedSnapshot,
        'pendingCount': pendingSnapshot,
        'pending_count': pendingSnapshot,
        'pending': pendingSnapshot,
        'absentCount': absentCnt,
        'absent_count': absentCnt,
        'absent': absentCnt,
        'rate': ratePct,
        'presentRate': ratePct,
        'students': rptStudents,
      };

      final reportResult = await _attendanceRepo.saveReport(
        token: auth.token!,
        report: report,
      );
      reportResult.when(
        success: (_) {
          logDebug('Report saved');
          WebSocketService.instance.sendMessage({
            'type': 'REPORT_SAVED',
            'report': report,
            'timestamp': DateTime.now().toIso8601String(),
          });
          logDebug('📡 Broadcasted REPORT_SAVED');
        },
        failure: (e) => logDebug('Save report failed: $e'),
      );
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
        _confirmedCount = 0;
        _pendingCount = 0;
        _attendanceRecords = [];
      });

      _snack('Camera closed - Report saved', const Color(0xFF0EA5E9));
      _startContinuousSync();
    }
  }

  // ============================================
  // Timers
  // ============================================
  void _startHeartbeat(String sid, String token) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _attendanceRepo.heartbeat(sessionId: sid, token: token);
    });
  }

  void _startPolling(String sid, String token) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final result =
          await _attendanceRepo.getSessionData(sessionId: sid, token: token);
      if (!mounted) return;
      result.when(
        success: (data) {
          final recs =
              (data['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final sessionPhase =
              (data['session']?['phase'] ?? data['phase']) as String?;
          final qrEndTimeStr = (data['session']?['qrPhaseEndTime'] ??
              data['qrPhaseEndTime']) as String?;
          final qrEndTime =
              qrEndTimeStr != null ? DateTime.tryParse(qrEndTimeStr) : null;

          if (sessionPhase == 'qr' &&
              _phase == SessionPhase.active &&
              qrEndTime != null) {
            final remaining = qrEndTime.difference(DateTime.now());
            final qrStartStr = (data['session']?['qrPhaseStartTime'] ??
                data['qrPhaseStartTime']) as String?;
            setState(() {
              _phase = SessionPhase.confirming;
              _sessionEndTime = qrEndTime;
              _lectureEndedAt ??=
                  DateTime.tryParse(qrStartStr ?? '') ?? DateTime.now();
              _confirmRemaining =
                  remaining.isNegative ? Duration.zero : remaining;
              _attendanceRecords = recs;
              _confirmedCount =
                  recs.where((r) => r['status'] == 'confirmed').length;
              _pendingCount =
                  recs.where((r) => r['status'] == 'pending').length;
            });
            _startConfirmTimer();
            _snack('QR mode synced from server', Colors.orange);
          } else if (!_recentLocalEdit) {
            setState(() {
              _attendanceRecords = recs;
              _confirmedCount =
                  recs.where((r) => r['status'] == 'confirmed').length;
              _pendingCount =
                  recs.where((r) => r['status'] == 'pending').length;
            });
          }
        },
        failure: (e) {
          if (e is ServerException &&
              e.statusCode == 404 &&
              _phase != SessionPhase.none) {
            _snack('Session closed from another device',
                const Color(0xFF0EA5E9));
            _confirmTimer?.cancel();
            _pollTimer?.cancel();
            _heartbeatTimer?.cancel();
            _resetSession();
          }
        },
      );
    });
  }

  // ============================================
  // Manual Attendance — managed client-side and POSTed as a whole to
  // /api/attendance-session-data (the same store the camera + website use),
  // because the server has no per-student manual-attendance endpoint. The
  // action mirrors instantly to the website (server broadcasts
  // attendance-updated) and vice-versa.
  // ============================================
  Future<void> _pushAttendance(List<Map<String, dynamic>> records) async {
    if (_activeSessionId == null) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) return;
    final pending = records.where((r) => r['status'] == 'pending').toList();
    _lastLocalEdit = DateTime.now();
    setState(() {
      _attendanceRecords = records;
      _confirmedCount = records.where((r) => r['status'] == 'confirmed').length;
      _pendingCount = pending.length;
    });
    final result = await _attendanceRepo.pushSessionData(
      sessionId: _activeSessionId!,
      token: auth.token!,
      records: records,
      pending: pending,
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      _snack('Error syncing attendance', Colors.red);
    }
  }

  Map<String, dynamic>? _recOf(Student s) =>
      _attendanceRecords.cast<Map<String, dynamic>?>().firstWhere(
            (r) =>
                r?['student_id'] == s.id ||
                r?['studentId'] == s.id ||
                r?['student_id_number'] == s.studentId,
            orElse: () => null,
          );

  String _statusOf(Student s) => (_recOf(s)?['status'] ?? 'absent').toString();

  bool _isActedOn(Student s) {
    final rec = _recOf(s);
    if (rec == null) return false;
    return rec['status'] == 'confirmed' || rec['rejected'] == true;
  }

  Map<String, dynamic> _recordFor(Student s, String status,
      {bool rejected = false}) {
    final existing = _recOf(s);
    final rec = existing != null
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    final auth = context.read<AuthCubit>().state;
    final now = DateTime.now().toIso8601String();
    rec['student_id'] = s.id;
    rec['studentId'] = s.id;
    rec['student_id_number'] = s.studentId;
    rec['student_name'] = s.name;
    rec['studentName'] = s.name;
    rec['status'] = status;
    rec['confirmed'] = status == 'confirmed';
    rec.remove('comment');
    if (status == 'confirmed') {
      rec['rejected'] = false;
      rec['method'] = rec['confirmedByQR'] == true ? 'QR' : 'Manual';
      rec['confirmed_at'] = rec['confirmed_at'] ?? now;
      rec['confirmedAt'] = rec['confirmed_at'];
      rec['confirmed_by'] = auth.user?.name ?? 'Doctor';
    } else if (rejected) {
      rec['rejected'] = true;
      rec['method'] = 'Manual';
      rec['confirmed'] = false;
      rec['rejected_at'] = now;
      rec.remove('confirmed_at');
      rec.remove('confirmedAt');
    }
    return rec;
  }

  Future<void> _applyStatus(Student student, String status,
      {bool rejected = false}) async {
    final list = _attendanceRecords
        .map((r) => Map<String, dynamic>.from(r))
        .where((r) =>
            r['student_id'] != student.id &&
            r['studentId'] != student.id &&
            r['student_id_number'] != student.studentId)
        .toList();
    if (status == 'confirmed' || rejected) {
      list.add(_recordFor(student, status, rejected: rejected));
    }
    await _pushAttendance(list);
  }

  Future<void> _confirmStudent(Student s) => _applyStatus(s, 'confirmed');

  Future<void> _rejectStudent(Student s) =>
      _applyStatus(s, 'absent', rejected: true);

  Future<void> _bulkPending(bool confirm) async {
    final pending = (_sessionStudents ?? [])
        .where((s) => _statusOf(s) == 'pending')
        .toList();
    if (pending.isEmpty) {
      _snack('No pending students', Colors.orange);
      return;
    }
    final list =
        _attendanceRecords.map((r) => Map<String, dynamic>.from(r)).toList();
    for (final s in pending) {
      list.removeWhere((r) =>
          r['student_id'] == s.id ||
          r['studentId'] == s.id ||
          r['student_id_number'] == s.studentId);
      list.add(confirm
          ? _recordFor(s, 'confirmed')
          : _recordFor(s, 'absent', rejected: true));
    }
    await _pushAttendance(list);
    _snack(
        '${pending.length} pending student(s) ${confirm ? 'confirmed' : 'rejected'}',
        confirm ? Colors.green : Colors.red);
  }

  Future<void> _confirmAllPending() => _bulkPending(true);
  Future<void> _rejectAllPending() => _bulkPending(false);

  bool get _recentLocalEdit =>
      _lastLocalEdit != null &&
      DateTime.now().difference(_lastLocalEdit!) < const Duration(seconds: 3);

  Future<void> _refreshAttendanceNow() async {
    if (_activeSessionId == null || _recentLocalEdit) return;
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null) return;
    final result = await _attendanceRepo.getSessionData(
      sessionId: _activeSessionId!,
      token: auth.token!,
    );
    if (!mounted) return;
    result.when(
      success: (data) {
        final recs =
            (data['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _attendanceRecords = recs;
          _confirmedCount =
              recs.where((r) => r['status'] == 'confirmed').length;
          _pendingCount = recs.where((r) => r['status'] == 'pending').length;
        });
      },
      failure: (_) {},
    );
  }

  // ============================================
  // Dialogs
  // ============================================
  // Manual confirm / reject dialog. [action] is 'confirm' or 'reject'.
  // This action is FINAL — once confirmed or rejected it cannot be undone.
  void _showManualAttendanceDialog(Student student, String action) {
    final isConfirm = action == 'confirm';
    final accent =
        isConfirm ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final title =
        isConfirm ? 'Confirm Attendance Manually' : 'Reject Attendance';
    final body = isConfirm
        ? 'Confirm attendance for ${student.name}? This marks the student as present. This action is final and cannot be undone.'
        : 'Reject attendance for ${student.name}? This marks the student as absent. This action is final and cannot be undone.';
    final icon = isConfirm ? Icons.check : Icons.close;
    final btnLabel = isConfirm ? 'Confirm Attendance' : 'Reject Attendance';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26.sp),
            ),
            SizedBox(height: 12.h),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 17.sp)),
          ],
        ),
        content: Text(
          body,
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 13.sp, color: Theme.of(context).hintColor),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isConfirm) {
                _confirmStudent(student);
              } else {
                _rejectStudent(student);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r))),
            child: Text(btnLabel),
          ),
        ],
      ),
    );
  }

  void _showActivateConfirmDialog(Lecture lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Row(children: [
          Icon(Icons.play_circle, color: Colors.green, size: 28.sp),
          SizedBox(width: 12.w),
          Text('Start $_term',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start "${lecture.subjectName}"?'),
            SizedBox(height: 12.h),
            _dialogRow(Icons.videocam, 'Camera starts on host'),
            _dialogRow(Icons.people, 'Only enrolled students'),
            _dialogRow(
                Icons.qr_code, '30 min QR after ${_term.toLowerCase()}'),
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
                    borderRadius: BorderRadius.circular(12.r))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Row(children: [
          Icon(Icons.stop_circle, color: Colors.orange, size: 28.sp),
          SizedBox(width: 12.w),
          Text('End $_term',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('End "${lecture.subjectName}"?'),
            SizedBox(height: 8.h),
            Text('$_confirmedCount confirmed, $_pendingCount pending',
                style: TextStyle(
                    fontSize: 12.sp, color: Theme.of(context).hintColor)),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r)),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18.sp),
                SizedBox(width: 8.w),
                Flexible(
                    child: Text('Camera stays 30 min for QR',
                        style: TextStyle(fontSize: 11.sp, color: Colors.orange))),
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
                    borderRadius: BorderRadius.circular(12.r))),
            child: Text('End $_term'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Row(children: [
          Icon(Icons.warning, color: Colors.red, size: 28.sp),
          SizedBox(width: 12.w),
          const Text('Close Now?', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    borderRadius: BorderRadius.circular(12.r))),
            child: const Text('Close & Send'),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(children: [
        Icon(icon, size: 16.sp, color: Theme.of(context).hintColor),
        SizedBox(width: 8.w),
        Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.sp, color: Theme.of(context).hintColor))),
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
    final isTA = user?.isTeachingAssistant ?? false;
    final doctorId = _ownerId(user);

    List<Lecture> doctorLectures;
    if (isTA) {
      final taId = user?.id ?? 0;
      doctorLectures = dataState.allSections
          .where((s) =>
              s.taId == taId &&
              (s.semester == null || s.semester == currentSemester))
          .map(_sectionToLecture)
          .toList();
    } else {
      final doctorSubjects = dataState.subjects
          .where(
              (s) => s.doctorId == doctorId && s.semester == currentSemester)
          .toList();
      final doctorSubjectIds = doctorSubjects.map((s) => s.id).toList();
      doctorLectures = dataState.lectures
          .where((l) => doctorSubjectIds.contains(l.subjectId))
          .toList();
    }

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
      body: AppSkeleton(
        enabled: dataState.loadingState.isLoading,
        child: RefreshIndicator(
        onRefresh: _refreshData,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
              padding: EdgeInsets.all(4.r),
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(40.r),
              ),
              child: Row(
                children: [
                  _buildTab(_isTA ? 'Sections' : 'Lectures',
                      Icons.calendar_today_rounded, !_showActiveSessions, () {
                    setState(() => _showActiveSessions = false);
                  }),
                  _buildTab(
                    _phase == SessionPhase.confirming ? 'QR Mode' : 'Live',
                    _phase == SessionPhase.confirming
                        ? Icons.qr_code
                        : Icons.qr_code_scanner_rounded,
                    _showActiveSessions,
                    () => setState(() => _showActiveSessions = true),
                  ),
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
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: locked
                ? Colors.grey.withValues(alpha: 0.15)
                : (isActive
                    ? Theme.of(context).primaryColor
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(36.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16.sp, color: fgColor),
              SizedBox(width: 6.w),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                      color: fgColor)),
              if (locked) ...[
                SizedBox(width: 6.w),
                Icon(Icons.lock_rounded, size: 14.sp, color: Colors.grey),
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
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline,
                    size: 16.sp, color: Theme.of(context).primaryColor),
                SizedBox(width: 8.w),
                Text(
                  'Showing ${_term.toLowerCase()}s for Semester $currentSemester',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.r),
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
                SizedBox(height: 10.h),
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
        SliverToBoxAdapter(child: SizedBox(height: 16.h)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, dayIndex) {
              final day = daysToShow[dayIndex];
              final dayLectures = lecturesByDay[day] ?? [];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                    const Color(0xFF0284C7).withValues(alpha: 0.04),
                  ]),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border(
                      left: BorderSide(
                          color: Theme.of(context).primaryColor, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(12.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(day,
                              style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B))),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12.r)),
                            child: Text('${dayLectures.length}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.sp,
                                    color: const Color(0xFF0EA5E9))),
                          ),
                        ],
                      ),
                    ),
                    ...dayLectures.map((lecture) => Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 4.h),
                          child: _buildLectureCard(lecture),
                        )),
                    SizedBox(height: 8.h),
                  ],
                ),
              );
            },
            childCount: daysToShow.length,
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: 80.h)),
      ],
    );
  }

  Widget _buildLectureCard(Lecture lecture) {
    final isActive = _activeSession?.id == lecture.id;
    final busy = _phase != SessionPhase.none && !isActive;
    final phaseColor =
        _phase == SessionPhase.confirming ? Colors.orange : Colors.green;

    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
        border: isActive ? Border.all(color: phaseColor, width: 1) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: isActive ? phaseColor : Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.subjectName,
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color:
                            _isDark ? Colors.white : const Color(0xFF1E293B))),
                SizedBox(height: 2.h),
                Row(children: [
                  Icon(Icons.access_time,
                      size: 10.sp, color: const Color(0xFF94A3B8)),
                  SizedBox(width: 2.w),
                  Text(lecture.timeDisplay,
                      style: TextStyle(
                          fontSize: 10.sp, color: const Color(0xFF94A3B8))),
                  SizedBox(width: 10.w),
                  Icon(Icons.location_on,
                      size: 10.sp, color: const Color(0xFF94A3B8)),
                  SizedBox(width: 2.w),
                  Text(lecture.locationName,
                      style: TextStyle(
                          fontSize: 10.sp, color: const Color(0xFF94A3B8))),
                ]),
                Text(
                    'Level ${lecture.level} - ${lecture.department ?? 'General'}',
                    style:
                        TextStyle(fontSize: 9.sp, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Builder(builder: (ctx) {
            final user = ctx.watch<AuthCubit>().state.user;
            if (!_canActivateSubject(lecture.subjectId, user)) {
              return Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12.sp, color: Colors.grey),
                    SizedBox(width: 4.w),
                    Text('Locked',
                        style: TextStyle(
                            fontSize: 11.sp,
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
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r)),
              ),
              child: _isActivating
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      isActive
                          ? (_phase == SessionPhase.confirming ? 'QR...' : 'End')
                          : (busy ? 'Busy' : 'Activate'),
                      style: TextStyle(
                          fontSize: 11.sp, fontWeight: FontWeight.bold)),
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
                size: 80.sp,
                color:
                    _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400),
            SizedBox(height: 16.h),
            Text('No active sessions',
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w500,
                    color: _isDark
                        ? const Color(0xFF94A3B8)
                        : Colors.grey.shade600)),
            SizedBox(height: 8.h),
            Text('Activate a ${_term.toLowerCase()} to start attendance',
                style: TextStyle(
                    fontSize: 13.sp,
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
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                phaseColor.withValues(alpha: 0.15),
                phaseColor.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: phaseColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(_activeSession!.subjectName,
                          style: TextStyle(
                              fontSize: 20.sp, fontWeight: FontWeight.bold))),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                        color: phaseColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                            color: phaseColor.withValues(alpha: 0.4))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(
                              color: phaseColor, shape: BoxShape.circle)),
                      SizedBox(width: 4.w),
                      Text(isConfirming ? 'QR MODE' : 'LIVE',
                          style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: phaseColor)),
                    ]),
                  ),
                ]),
                if (isConfirming) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r)),
                    child: Row(children: [
                      Icon(Icons.timer, color: Colors.orange, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text('Camera closes in ${_fmtDur(_confirmRemaining)}',
                          style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange)),
                    ]),
                  ),
                ],
                SizedBox(height: 8.h),
                Row(children: [
                  Icon(Icons.access_time,
                      size: 14.sp, color: const Color(0xFF94A3B8)),
                  SizedBox(width: 4.w),
                  Text(_activeSession!.timeDisplay,
                      style: TextStyle(
                          fontSize: 12.sp, color: const Color(0xFF94A3B8))),
                  SizedBox(width: 16.w),
                  Icon(Icons.location_on,
                      size: 14.sp, color: const Color(0xFF94A3B8)),
                  SizedBox(width: 4.w),
                  Text(_activeSession!.locationName,
                      style: TextStyle(
                          fontSize: 12.sp, color: const Color(0xFF94A3B8))),
                ]),
                SizedBox(height: 20.h),
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
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showStudentList = !_showStudentList),
              icon: Icon(
                  _showStudentList ? Icons.visibility_off : Icons.visibility,
                  size: 18.sp),
              label: Text(_showStudentList
                  ? 'Hide Students'
                  : 'View Students ($totalStudents)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                side: const BorderSide(color: Color(0xFF0EA5E9)),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ),
          if (_showStudentList &&
              _sessionStudents != null &&
              _sessionStudents!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12.r),
                          topRight: Radius.circular(12.r)),
                    ),
                    child: Row(children: [
                      Expanded(
                          flex: 5,
                          child: Text('STUDENT',
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0EA5E9)))),
                      SizedBox(
                          width: 62.w,
                          child: Text('STATUS',
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0EA5E9)),
                              textAlign: TextAlign.center)),
                      SizedBox(
                          width: 86.w,
                          child: Text('ACTIONS',
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0EA5E9)),
                              textAlign: TextAlign.center)),
                    ]),
                  ),
                  ..._sessionStudents!.map((student) {
                    final rec = _recOf(student);
                    final status = (rec?['status'] ?? 'absent').toString();
                    final acted = _isActedOn(student);
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
                    String subtitle = student.studentId;
                    if (status == 'confirmed') {
                      final m = rec?['confirmedByQR'] == true
                          ? 'QR'
                          : (rec?['method'] ?? 'Manual').toString();
                      final t = _fmtClock(
                          rec?['confirmed_at'] ?? rec?['confirmedAt']);
                      subtitle = t.isEmpty
                          ? '${student.studentId}  •  $m'
                          : '${student.studentId}  •  $m  •  $t';
                    } else if (rec?['rejected'] == true) {
                      subtitle = '${student.studentId}  •  Rejected manually';
                    } else if (status == 'pending') {
                      subtitle = '${student.studentId}  •  Face detected';
                    }

                    return Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: _isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade200)),
                      ),
                      child: Row(children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name,
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B))),
                              SizedBox(height: 2.h),
                              Text(subtitle,
                                  style: TextStyle(
                                      fontSize: 9.sp,
                                      color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 62.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4.w, vertical: 3.h),
                            decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10.r)),
                            child: Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor),
                                textAlign: TextAlign.center),
                          ),
                        ),
                        SizedBox(
                          width: 86.w,
                          child: acted
                              ? Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                          alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(8.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock_outline,
                                            size: 13.sp, color: statusColor),
                                        SizedBox(width: 4.w),
                                        Text('Final',
                                            style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor)),
                                      ],
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _showManualAttendanceDialog(
                                              student, 'confirm'),
                                      child: Container(
                                        width: 30.w,
                                        height: 30.w,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                        ),
                                        child: Icon(Icons.check,
                                            size: 17.sp,
                                            color:
                                                const Color(0xFF10B981)),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    GestureDetector(
                                      onTap: () =>
                                          _showManualAttendanceDialog(
                                              student, 'reject'),
                                      child: Container(
                                        width: 30.w,
                                        height: 30.w,
                                        decoration: BoxDecoration(
                                          color: Colors.red
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                        ),
                                        child: Icon(Icons.close,
                                            size: 17.sp,
                                            color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ]),
                    );
                  }),
                  Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12.r),
                            bottomRight: Radius.circular(12.r)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _confirmAllPending,
                            icon: Icon(Icons.check_circle_outline,
                                size: 14.sp),
                            label: Text('Confirm All Pending',
                                style: TextStyle(fontSize: 10.sp)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(
                                  color: Color(0xFF10B981)),
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _rejectAllPending,
                            icon: Icon(Icons.cancel_outlined, size: 14.sp),
                            label: Text('Reject All Pending',
                                style: TextStyle(fontSize: 10.sp)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
          SizedBox(height: 20.h),
          if (_phase == SessionPhase.active)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showEndSessionConfirmDialog(_activeSession!),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r))),
                child: Text('End $_term (Start QR)',
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.bold)),
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
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r))),
                child: Text('Close Now & Send Report',
                    style:
                        TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
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
                fontSize: 28.sp, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 4.h),
        Text(label,
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF94A3B8))),
      ]),
    );
  }

  Widget _buildDropdown<T>(
      T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20.r),
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
              fontSize: 12.sp),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
