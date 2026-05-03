// lib/screens/sections/doctor/doctor_attendance.dart
// ✅ Fixes:
//   - End Session لا يحذف الـ session (الكاميرا تفضل شغالة 30 دقيقة)
//   - فقط Finalize بعد 30 دقيقة هو اللي يحذف الـ session ويقفل الكاميرا
//   - الوقت مظبوط (start قبل end)
//   - WebView للكاميرا

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/lecture.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';
import '../../../core/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum SessionPhase { none, active, confirming }

class DoctorAttendance extends StatefulWidget {
  const DoctorAttendance({super.key});

  @override
  State<DoctorAttendance> createState() => _DoctorAttendanceState();
}

class _DoctorAttendanceState extends State<DoctorAttendance> {
  String _selectedDay = '';
  bool _showActiveSessions = false;
  int _selectedSemester = 0;
  int _selectedLevel = 0;

  SessionPhase _phase = SessionPhase.none;
  Lecture? _activeSession;
  String? _activeSessionId;
  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;
  List<Student>? _sessionStudents;
  bool _showStudentList = false;
  bool _isActivating = false;
  bool _isEnding = false;
  bool _isCameraOpen = false;

  List<Map<String, dynamic>> _attendanceRecords = [];
  int _confirmedCount = 0;
  int _pendingCount = 0;

  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  Timer? _confirmationTimer;
  Duration _confirmationRemaining = Duration.zero;

  final List<String> _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'];
  final List<int> _levels = [1, 2, 3, 4];
  static const _confirmDuration = Duration(minutes: 30);

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _pollTimer?.cancel();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  // ============================================
  // 1️⃣ ACTIVATE
  // ============================================
  Future<void> _activateSession(Lecture lecture) async {
    setState(() => _isActivating = true);
    final auth = context.read<AuthCubit>().state;
    final token = auth.token;
    final user = auth.user;
    if (token == null || user == null) { _msg('Not authenticated', Colors.red); setState(() => _isActivating = false); return; }

    try {
      final sessionId = 'SES-${DateTime.now().millisecondsSinceEpoch}-${lecture.id}';
      final now = DateTime.now();

      // Create session
      final res = await http.post(Uri.parse('${AppConstants.baseUrl}/api/active-sessions'), headers: _h(token), body: jsonEncode({
        'sessionId': sessionId, 'lectureId': lecture.id, 'doctorId': user.id, 'doctorName': user.name,
        'subjectName': lecture.subjectName, 'level': lecture.level, 'department': lecture.department,
        'startTime': now.toIso8601String(), 'deviceInfo': {'source': 'mobile_app'},
      })).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) { _msg('Failed to create session', Colors.red); setState(() => _isActivating = false); return; }

      // Open camera
      bool camOk = false;
      try {
        final camRes = await http.post(Uri.parse('${AppConstants.baseUrl}/api/camera/request'), headers: _h(token), body: jsonEncode({
          'sessionId': sessionId, 'lectureId': lecture.id, 'doctorName': user.name,
        })).timeout(const Duration(seconds: 10));
        camOk = jsonDecode(camRes.body)['success'] == true;
      } catch (_) {}

      // ignore: use_build_context_synchronously
      final ds = context.read<DataCubit>().state;
      final students = ds.students.where((s) => s.level == lecture.level && s.department == lecture.department).toList();

      setState(() {
        _phase = SessionPhase.active;
        _activeSession = lecture; _activeSessionId = sessionId;
        _sessionStartTime = now; _sessionEndTime = null;
        _sessionStudents = students; _showActiveSessions = true;
        _isCameraOpen = camOk; _isActivating = false;
        _confirmedCount = 0; _pendingCount = 0; _attendanceRecords = [];
      });

      _startHeartbeat(sessionId, token);
      _startPolling(sessionId, token);
      _msg('Session started: ${lecture.subjectName}${camOk ? ' • Camera running' : ''}', Colors.green);
    } catch (e) { _msg('Error: $e', Colors.red); setState(() => _isActivating = false); }
  }

  // ============================================
  // 2️⃣ END SESSION — الكاميرا تفضل شغالة!
  // ============================================
  Future<void> _endSession() async {
    if (_activeSessionId == null) return;
    setState(() => _isEnding = true);

    // ✅ Fix: مش بنحذف الـ session من السيرفر — الكاميرا تفضل شغالة
    // بس بنغير الـ phase محلياً لـ confirming
    final now = DateTime.now();

    setState(() {
      _phase = SessionPhase.confirming;
      _sessionEndTime = now;
      _isEnding = false;
      _confirmationRemaining = _confirmDuration;
    });

    // Heartbeat يفضل شغال عشان السيرفر يعرف الـ session لسه حية
    // (مش بنقفله)

    // Start 30 min countdown
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final elapsed = DateTime.now().difference(_sessionEndTime!);
      final remaining = _confirmDuration - elapsed;
      setState(() => _confirmationRemaining = remaining);
      if (remaining.isNegative) { timer.cancel(); _finalizeSession(); }
    });

    _msg('Lecture ended • QR confirmation open for 30 min • Camera still running', Colors.orange);
  }

  // ============================================
  // 3️⃣ FINALIZE — بعد 30 دقيقة: يحذف الـ session + يقفل الكاميرا + يبعت report
  // ============================================
  Future<void> _finalizeSession() async {
    _confirmationTimer?.cancel();
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();

    final auth = context.read<AuthCubit>().state;
    final token = auth.token;
    if (token == null) return;

    try {
      // ✅ الآن بنحذف الـ session — الكاميرا هتشوف "Session Ended" وتقفل
      await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/active-sessions/$_activeSessionId'),
        headers: _h(token),
      ).timeout(const Duration(seconds: 10));

      // ✅ Auto report — الأوقات مظبوطة (start < end)
      await http.post(Uri.parse('${AppConstants.baseUrl}/api/attendance-reports'), headers: _h(token), body: jsonEncode({
        'sessionId': _activeSessionId,
        'lectureId': _activeSession?.id,
        'doctorId': auth.user?.id,
        'doctorName': auth.user?.name,
        'subjectName': _activeSession?.subjectName,
        'level': _activeSession?.level,
        'department': _activeSession?.department,
        'createdAt': _sessionStartTime?.toIso8601String(),    // ✅ وقت البداية
        'endedAt': _sessionEndTime?.toIso8601String(),         // ✅ وقت نهاية المحاضرة
        'cameraClosedAt': DateTime.now().toIso8601String(),    // ✅ وقت قفل الكاميرا
        'totalStudents': _sessionStudents?.length ?? 0,
        'presentCount': _confirmedCount,
        'pendingCount': _pendingCount,
        'absentCount': (_sessionStudents?.length ?? 0) - _confirmedCount - _pendingCount,
        'students': _buildReportStudents(),
      })).timeout(const Duration(seconds: 10));
    } catch (e) { debugPrint('⚠️ Finalize error: $e'); }

    setState(() {
      _phase = SessionPhase.none; _activeSession = null; _activeSessionId = null;
      _sessionStartTime = null; _sessionEndTime = null; _sessionStudents = null;
      _isCameraOpen = false; _confirmedCount = 0; _pendingCount = 0; _attendanceRecords = [];
    });

    _msg('Camera closed • Report saved to Reports', const Color(0xFF0EA5E9));
  }

  List<Map<String, dynamic>> _buildReportStudents() {
    if (_sessionStudents == null) return _attendanceRecords;
    return _sessionStudents!.map((s) {
      final rec = _attendanceRecords.cast<Map<String, dynamic>?>().firstWhere(
        (r) => r?['student_id'] == s.id || r?['student_id_number'] == s.studentId, orElse: () => null);
      final faceAt = rec?['face_detected_at'] ?? rec?['created_at'] ?? '';
      final qrAt = rec?['confirmed_at'] ?? rec?['qr_scanned_at'] ?? '';
      String? duration;
      if (faceAt.toString().isNotEmpty && qrAt.toString().isNotEmpty) {
        try { final d = DateTime.parse(qrAt).difference(DateTime.parse(faceAt)); duration = d.inHours > 0 ? '${d.inHours}h ${d.inMinutes % 60}m' : '${d.inMinutes}m'; } catch (_) {}
      }
      return {'student_id': s.id, 'student_id_number': s.studentId, 'student_name': s.name, 'status': rec?['status'] ?? 'absent',
        'face_detected_at': faceAt, 'qr_scanned_at': qrAt, 'confirmed_by': rec?['confirmed_by'], 'attendance_duration': duration};
    }).toList();
  }

  // ============================================
  // Timers
  // ============================================
  void _startHeartbeat(String sid, String token) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try { await http.post(Uri.parse('${AppConstants.baseUrl}/api/active-sessions/$sid/heartbeat'), headers: _h(token)); } catch (_) {}
    });
  }

  void _startPolling(String sid, String token) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/attendance-session-data/$sid'), headers: _h(token)).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200 && mounted) {
          final data = jsonDecode(res.body);
          final recs = (data['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          setState(() { _attendanceRecords = recs; _confirmedCount = recs.where((r) => r['status'] == 'confirmed').length; _pendingCount = recs.where((r) => r['status'] == 'pending').length; });
        }
      } catch (_) {}
    });
  }

  // ============================================
  // 4️⃣ Camera View — WebView
  // ============================================
  void _openCameraView() {
    if (_activeSessionId == null) return;
    final auth = context.read<AuthCubit>().state;
    final token = auth.token ?? '';
    final cameraUrl = '${AppConstants.baseUrl}/camera.html'
        '?sessionId=$_activeSessionId'
        '&lectureId=${_activeSession?.id}'
        '&doctorId=${auth.user?.id}'
        '&doctorName=${Uri.encodeComponent(auth.user?.name ?? '')}'
        '&token=$token';

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CameraWebViewScreen(url: cameraUrl, subjectName: _activeSession?.subjectName ?? ''),
    ));
  }

  Future<void> _retryCam() async {
    final auth = context.read<AuthCubit>().state;
    if (auth.token == null || _activeSessionId == null) return;
    try {
      final res = await http.post(Uri.parse('${AppConstants.baseUrl}/api/camera/request'), headers: _h(auth.token!), body: jsonEncode({
        'sessionId': _activeSessionId, 'lectureId': _activeSession?.id, 'doctorName': auth.user?.name})).timeout(const Duration(seconds: 10));
      if (jsonDecode(res.body)['success'] == true) { setState(() => _isCameraOpen = true); _msg('Camera opened!', Colors.green); }
      else { _msg('Host not connected', Colors.red); }
    } catch (e) { _msg('Error: $e', Colors.red); }
  }

  // ============================================
  // Helpers
  // ============================================
  Map<String, String> _h(String t) => {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'};
  void _msg(String m, Color c) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
  String _fmtDur(Duration d) { if (d.isNegative) return '0:00'; return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}'; }
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ============================================
  // Dialogs
  // ============================================
  void _showActivateConfirm(Lecture l) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(children: [Icon(Icons.play_circle, color: Colors.green, size: 28), SizedBox(width: 12), Text('Start Lecture', style: TextStyle(fontWeight: FontWeight.bold))]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('"${l.subjectName}"'), const SizedBox(height: 12),
        _infoRow(Icons.videocam, 'Camera starts on host'), _infoRow(Icons.qr_code, '30 min QR window after end'), _infoRow(Icons.analytics, 'Report auto-generated'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _activateSession(l); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Start'))],
    ));
  }

  void _showEndConfirm(Lecture l) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(children: [Icon(Icons.stop_circle, color: Colors.orange, size: 28), SizedBox(width: 12), Text('End Lecture', style: TextStyle(fontWeight: FontWeight.bold))]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('"${l.subjectName}"'), const SizedBox(height: 8),
        Text('$_confirmedCount confirmed, $_pendingCount pending', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [Icon(Icons.info_outline, color: Colors.orange, size: 18), SizedBox(width: 8),
            Flexible(child: Text('Camera stays open 30 min for QR', style: TextStyle(fontSize: 11, color: Colors.orange)))])),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: _isEnding ? null : () { Navigator.pop(ctx); _endSession(); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('End Lecture'))],
    ));
  }

  void _showForceFinalize() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(children: [Icon(Icons.warning, color: Colors.red, size: 28), SizedBox(width: 12), Text('Close Now?', style: TextStyle(fontWeight: FontWeight.bold))]),
      content: const Text('Camera will close and report sent now. Students without QR stay as Pending.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Wait')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _finalizeSession(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Close & Send'))],
    ));
  }

  Widget _infoRow(IconData i, String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(i, size: 16, color: Theme.of(context).hintColor), const SizedBox(width: 8), Flexible(child: Text(t, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)))]));

  // ============================================
  // BUILD
  // ============================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final ds = context.watch<DataCubit>().state;
    final doctorId = auth.user?.id ?? 0;
    List<Subject> subs = ds.subjects.where((s) => s.doctorId == doctorId).toList();
    final sIds = subs.map((s) => s.id).toList();
    List<Lecture> lecs = ds.lectures.where((l) => sIds.contains(l.subjectId)).toList();
    if (_selectedLevel != 0) lecs = lecs.where((l) => l.level == _selectedLevel).toList();
    if (_selectedSemester > 0) { final ids = subs.where((s) => s.semester == _selectedSemester).map((s) => s.id).toList(); lecs = lecs.where((l) => ids.contains(l.subjectId)).toList(); }
    if (_selectedDay.isNotEmpty) lecs = lecs.where((l) => l.day == _selectedDay).toList();
    final days = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    final Map<String, List<Lecture>> byDay = {};
    for (final d in days) { byDay[d] = lecs.where((l) => l.day == d).toList()..sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay)); }

    return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: Column(children: [
      // Tabs
      Container(margin: const EdgeInsets.fromLTRB(20, 16, 20, 12), padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(40)),
        child: Row(children: [
          _tabBtn('Lectures', Icons.calendar_today_rounded, !_showActiveSessions, () => setState(() => _showActiveSessions = false)),
          _tabBtn(_phase == SessionPhase.confirming ? 'QR Mode' : 'Live', _phase == SessionPhase.confirming ? Icons.qr_code : Icons.qr_code_scanner_rounded, _showActiveSessions, () => setState(() => _showActiveSessions = true)),
        ])),
      Expanded(child: _showActiveSessions ? _buildLive() : _buildLectures(byDay, days)),
    ]));
  }

  Widget _tabBtn(String l, IconData i, bool a, VoidCallback f) => Expanded(child: GestureDetector(onTap: f, child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: a ? Theme.of(context).primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(36)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, size: 16, color: a ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)), const SizedBox(width: 6),
      Text(l, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: a ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)))]),
  )));

  // ---- Lectures ----
  Widget _buildLectures(Map<String, List<Lecture>> byDay, List<String> days) {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200)),
        child: Column(children: [
          _dd<int>(_selectedLevel, [const DropdownMenuItem(value: 0, child: Text('All Levels')), ..._levels.map((l) => DropdownMenuItem(value: l, child: Text('Level $l')))], (v) => setState(() => _selectedLevel = v ?? 0)),
          const SizedBox(height: 10),
          _dd<int>(_selectedSemester, const [DropdownMenuItem(value: 0, child: Text('All Semesters')), DropdownMenuItem(value: 1, child: Text('Semester 1')), DropdownMenuItem(value: 2, child: Text('Semester 2'))], (v) => setState(() => _selectedSemester = v ?? 0)),
          const SizedBox(height: 10),
          _dd<String?>(_selectedDay.isEmpty ? null : _selectedDay, [const DropdownMenuItem<String?>(value: null, child: Text('All Days')), ..._days.map((d) => DropdownMenuItem<String?>(value: d, child: Text(d)))], (v) => setState(() => _selectedDay = v ?? '')),
        ]))),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverList(delegate: SliverChildBuilderDelegate((_, i) {
        final day = days[i]; final ls = byDay[day] ?? [];
        return Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0EA5E9).withValues(alpha: 0.08), const Color(0xFF0284C7).withValues(alpha: 0.04)]), borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: Theme.of(context).primaryColor, width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(day, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('${ls.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0EA5E9)))),
            ])),
            ...ls.map((l) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _lecCard(l))),
            const SizedBox(height: 8),
          ]));
      }, childCount: days.length)),
      const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
    ]);
  }

  Widget _lecCard(Lecture l) {
    final isActive = _activeSession?.id == l.id;
    final busy = _phase != SessionPhase.none && !isActive;
    final phaseColor = _phase == SessionPhase.confirming ? Colors.orange : Colors.green;
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: isActive ? Border.all(color: phaseColor) : null),
      child: Row(children: [
        Container(width: 3, height: 40, decoration: BoxDecoration(color: isActive ? phaseColor : Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.subjectName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          Row(children: [const Icon(Icons.access_time, size: 10, color: Color(0xFF94A3B8)), const SizedBox(width: 2), Text(l.timeDisplay, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))), const SizedBox(width: 10), const Icon(Icons.location_on, size: 10, color: Color(0xFF94A3B8)), const SizedBox(width: 2), Text(l.locationName, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))]),
          Text('Level ${l.level} - ${l.department ?? 'General'}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        ])),
        ElevatedButton(
          onPressed: isActive ? (_phase == SessionPhase.active ? () => _showEndConfirm(l) : null) : (busy || _isActivating ? null : () => _showActivateConfirm(l)),
          style: ElevatedButton.styleFrom(backgroundColor: isActive ? (_phase == SessionPhase.confirming ? Colors.orange : Colors.red) : (busy ? Colors.grey : Colors.green), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          child: _isActivating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(isActive ? (_phase == SessionPhase.confirming ? 'QR...' : 'End') : (busy ? 'Busy' : 'Activate'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]));
  }

  // ---- Live Session View ----
  Widget _buildLive() {
    if (_phase == SessionPhase.none) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.qr_code_scanner, size: 80, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400),
        const SizedBox(height: 16), Text('No active session', style: TextStyle(fontSize: 18, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
      ]));
    }
    final total = _sessionStudents?.length ?? 0;
    final absent = total - _confirmedCount - _pendingCount;
    final isConf = _phase == SessionPhase.confirming;
    final phaseColor = isConf ? Colors.orange : const Color(0xFF0EA5E9);

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Header
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [phaseColor.withValues(alpha: 0.15), phaseColor.withValues(alpha: 0.05)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: phaseColor.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_activeSession!.subjectName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: phaseColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: phaseColor.withValues(alpha: 0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: phaseColor, shape: BoxShape.circle)), const SizedBox(width: 4),
                Text(isConf ? 'QR MODE' : 'LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: phaseColor))])),
          ]),
          if (isConf) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [const Icon(Icons.timer, color: Colors.orange, size: 20), const SizedBox(width: 8), Text('Camera closes in ${_fmtDur(_confirmationRemaining)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange))]))],
          const SizedBox(height: 16),
          Row(children: [_big('$total', 'Total', Colors.white), _big('$_confirmedCount', 'Confirmed', const Color(0xFF10B981)), _big('$_pendingCount', 'Pending', const Color(0xFFF59E0B)), _big('$absent', 'Absent', const Color(0xFFEF4444))]),
        ])),
      const SizedBox(height: 16),

      // Camera
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isCameraOpen ? _openCameraView : _retryCam,
        icon: Icon(_isCameraOpen ? Icons.videocam : Icons.videocam_off, size: 20),
        label: Text(_isCameraOpen ? 'View Camera' : 'Camera Offline — Tap to Retry'),
        style: ElevatedButton.styleFrom(backgroundColor: _isCameraOpen ? const Color(0xFF10B981) : Colors.grey, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
      const SizedBox(height: 12),

      // Students
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => setState(() => _showStudentList = !_showStudentList),
        icon: Icon(_showStudentList ? Icons.visibility_off : Icons.visibility, size: 18), label: Text(_showStudentList ? 'Hide Students' : 'View Students ($total)'),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9), side: const BorderSide(color: Color(0xFF0EA5E9)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),

      if (_showStudentList && _sessionStudents != null)
        Container(margin: const EdgeInsets.only(top: 16), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
          child: Column(children: _sessionStudents!.map((s) {
            final rec = _attendanceRecords.cast<Map<String, dynamic>?>().firstWhere((r) => r?['student_id'] == s.id || r?['student_id_number'] == s.studentId, orElse: () => null);
            final st = rec?['status'] ?? 'absent';
            final col = st == 'confirmed' ? const Color(0xFF10B981) : st == 'pending' ? const Color(0xFFF59E0B) : Colors.red;
            final lab = st == 'confirmed' ? 'Present' : st == 'pending' ? 'Pending' : 'Absent';
            return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200))),
              child: Row(children: [Expanded(flex: 2, child: Text(s.studentId, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF0EA5E9)))),
                Expanded(flex: 3, child: Text(s.name, style: TextStyle(fontSize: 11, color: isDark ? Colors.white : const Color(0xFF1E293B)))),
                SizedBox(width: 70, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(lab, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: col), textAlign: TextAlign.center)))]));
          }).toList())),

      const SizedBox(height: 20),
      if (_phase == SessionPhase.active)
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isEnding ? null : () => _showEndConfirm(_activeSession!),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('End Lecture (Start QR)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))))
      else if (_phase == SessionPhase.confirming)
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _showForceFinalize,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Close Now & Send Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))),
    ]));
  }

  Widget _big(String v, String l, Color c) => Expanded(child: Column(children: [Text(v, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: c)), const SizedBox(height: 4), Text(l, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))]));

  Widget _dd<T>(T val, List<DropdownMenuItem<T>> items, ValueChanged<T?> fn) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200)),
    child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: val, isExpanded: true, dropdownColor: Theme.of(context).cardColor, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 12), items: items, onChanged: fn)));
}

// ============================================
// Camera WebView Screen
// ============================================
class _CameraWebViewScreen extends StatefulWidget {
  final String url;
  final String subjectName;
  const _CameraWebViewScreen({required this.url, required this.subjectName});

  @override
  State<_CameraWebViewScreen> createState() => _CameraWebViewScreenState();
}

class _CameraWebViewScreenState extends State<_CameraWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) { if (mounted) setState(() => _isLoading = false); },
        onWebResourceError: (err) { debugPrint('WebView error: ${err.description}'); },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.subjectName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isLoading) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () { setState(() => _isLoading = true); _controller.reload(); }),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_isLoading) const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      ]),
    );
  }
}
