import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/pdf_report_service.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/toast_message.dart';
import '../../../widgets/app_skeleton.dart';

class DoctorReports extends StatefulWidget {
  const DoctorReports({super.key});

  @override
  State<DoctorReports> createState() => _DoctorReportsState();
}

class _DoctorReportsState extends State<DoctorReports> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _error;
  bool _isDeleting = false;
  StreamSubscription? _reportSavedSub;
  StreamSubscription? _sessionEndedSub;

  // ── Filters (search bar like the website) ──────────────────────────────
  String? _filterSubject;
  int? _filterLevel;
  DateTime? _filterDate;

  // ── Enrolled-students cache: subjectId → set of student identifiers ────
  // Used to drop students that are NOT registered in the subject from a
  // report (the website sometimes saves a report with non-enrolled names).
  List<Map<String, dynamic>> _allSubjects = [];
  final Map<int, Set<String>> _enrolledCache = {};

  final AttendanceRepository _attendanceRepo = getIt<AttendanceRepository>();

  @override
  void initState() {
    super.initState();
    _loadReports();
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    final ws = WebSocketService.instance;

    _reportSavedSub = ws.reportSavedStream.listen((data) {
      if (!mounted) return;
      _loadReports();
      ToastMessage.showSuccess(context, 'New attendance report saved');
    });

    _sessionEndedSub = ws.sessionEndedStream.listen((data) {
      if (!mounted) return;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _loadReports();
      });
    });
  }

  @override
  void dispose() {
    _reportSavedSub?.cancel();
    _sessionEndedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthCubit>().state;
      final token = auth.token;
      final user = auth.user;
      final doctorId = user == null
          ? 0
          : (user.isTeachingAssistant ? user.id : user.effectiveDoctorId);
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final result = await _attendanceRepo.listReportsByDoctor(
        doctorId: doctorId,
        token: token,
      );
      if (!mounted) return;
      await result.when(
        success: (reports) async {
          reports.sort((a, b) => (b['createdAt'] ?? b['created_at'] ?? '')
              .compareTo(a['createdAt'] ?? a['created_at'] ?? ''));
          await _filterReportsToEnrolled(reports, token);
          if (!mounted) return;
          setState(() {
            _reports = reports;
            _isLoading = false;
          });
        },
        failure: (_) async {
          if (!mounted) return;
          setState(() {
            _error = 'Failed to load reports';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshReports() async {
    await _loadReports();
  }

  // ============================================
  // Enrollment filter — keep only registered students in each report
  // ============================================
  Future<void> _filterReportsToEnrolled(
      List<Map<String, dynamic>> reports, String token) async {
    if (_allSubjects.isEmpty) {
      final result = await _attendanceRepo.listSubjects(token: token);
      _allSubjects = result.valueOrNull ?? const [];
    }

    for (final report in reports) {
      final students =
          (report['students'] as List?)?.cast<Map<String, dynamic>>();
      if (students == null || students.isEmpty) continue;

      final subjectId = _resolveSubjectId(report);
      if (subjectId == null) continue;

      final enrolled = await _enrolledIds(subjectId, token);
      if (enrolled.isEmpty) continue;

      final filtered =
          students.where((s) => _isEnrolledStudent(s, enrolled)).toList();

      if (filtered.length != students.length) {
        final present =
            filtered.where((s) => s['status'] == 'confirmed').length;
        final pending = filtered.where((s) => s['status'] == 'pending').length;
        final absent = filtered.length - present - pending;
        report['students'] = filtered;
        report['totalStudents'] = filtered.length;
        report['total_students'] = filtered.length;
        report['enrolled'] = filtered.length;
        report['enrolled_count'] = filtered.length;
        report['presentCount'] = present;
        report['present_count'] = present;
        report['present'] = present;
        report['confirmed'] = present;
        report['pendingCount'] = pending;
        report['pending_count'] = pending;
        report['pending'] = pending;
        report['absentCount'] = absent;
        report['absent_count'] = absent;
        report['absent'] = absent;
        report['rate'] = filtered.isEmpty
            ? 0
            : (present / filtered.length * 100).round();
      }
    }
  }

  String _normName(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  bool _isEnrolledStudent(Map<String, dynamic> student, Set<String> enrolled) {
    for (final key in const [
      'student_id',
      'studentId',
      'student_id_number',
      'studentIdNumber',
      'id',
      'studentDbId'
    ]) {
      final v = student[key];
      if (v != null && enrolled.contains(v.toString())) return true;
    }
    final name = (student['student_name'] ??
            student['studentName'] ??
            student['name'] ??
            '')
        .toString();
    if (name.trim().isNotEmpty &&
        enrolled.contains('name:${_normName(name)}')) {
      return true;
    }
    return false;
  }

  int? _resolveSubjectId(Map<String, dynamic> report) {
    final raw = report['subjectId'] ?? report['subject_id'];
    if (raw != null) {
      final n = int.tryParse(raw.toString());
      if (n != null) return n;
    }
    final name = (report['subjectName'] ?? report['subject_name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (name.isEmpty) return null;
    for (final s in _allSubjects) {
      final sn = (s['name'] ?? '').toString().trim().toLowerCase();
      if (sn == name) {
        final id = s['id'];
        return id is int ? id : int.tryParse(id.toString());
      }
    }
    return null;
  }

  Future<Set<String>> _enrolledIds(int subjectId, String token) async {
    if (_enrolledCache.containsKey(subjectId)) {
      return _enrolledCache[subjectId]!;
    }
    final set = <String>{};
    final result = await _attendanceRepo.getEnrolledStudents(
      subjectId: subjectId,
      token: token,
    );
    for (final s in result.valueOrNull ?? const []) {
      if (s is Map) {
        if (s['id'] != null) set.add(s['id'].toString());
        if (s['student_id'] != null) set.add(s['student_id'].toString());
        final nm = (s['name'] ?? '').toString();
        if (nm.trim().isNotEmpty) set.add('name:${_normName(nm)}');
      }
    }
    _enrolledCache[subjectId] = set;
    return set;
  }

  // ============================================
  // Filters
  // ============================================
  DateTime? _reportDate(Map<String, dynamic> r) {
    final raw = (r['createdAt'] ??
            r['created_at'] ??
            r['date'] ??
            r['startTimeIso'] ??
            r['startTime'] ??
            '')
        .toString();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  List<String> get _subjectOptions {
    final set = <String>{};
    for (final r in _reports) {
      final n = (r['subjectName'] ?? r['subject_name'] ?? '').toString().trim();
      if (n.isNotEmpty) set.add(n);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<int> get _levelOptions {
    final set = <int>{};
    for (final r in _reports) {
      final lvl = r['level'];
      final n = lvl is int ? lvl : int.tryParse(lvl?.toString() ?? '');
      if (n != null) set.add(n);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _filteredReports {
    return _reports.where((r) {
      if (_filterSubject != null) {
        final n =
            (r['subjectName'] ?? r['subject_name'] ?? '').toString().trim();
        if (n != _filterSubject) return false;
      }
      if (_filterLevel != null) {
        final lvl = r['level'];
        final n = lvl is int ? lvl : int.tryParse(lvl?.toString() ?? '');
        if (n != _filterLevel) return false;
      }
      if (_filterDate != null) {
        final d = _reportDate(r);
        if (d == null ||
            d.year != _filterDate!.year ||
            d.month != _filterDate!.month ||
            d.day != _filterDate!.day) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilter =>
      _filterSubject != null || _filterLevel != null || _filterDate != null;

  // ============================================
  // DELETE REPORT
  // ============================================
  Future<void> _deleteReport(Map<String, dynamic> report, int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete the report for "${report['subjectName'] ?? report['subject_name'] ?? 'Unknown'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      // ignore: use_build_context_synchronously
      final auth = context.read<AuthCubit>().state;
      final token = auth.token;
      final reportId = report['id'];

      if (token == null) {
        // ignore: use_build_context_synchronously
        ToastMessage.showError(context, 'Not authenticated');
        return;
      }

      if (reportId == null) {
        // ignore: use_build_context_synchronously
        ToastMessage.showError(context, 'Report ID not found');
        return;
      }

      final result = await _attendanceRepo.deleteReport(
        reportId: reportId,
        token: token,
      );
      if (!mounted) return;
      result.when(
        success: (_) {
          setState(() => _reports.remove(report));
          ToastMessage.showSuccess(context, 'Report deleted successfully');
        },
        failure: (_) =>
            ToastMessage.showError(context, 'Failed to delete report'),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshReports,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: const Text('Attendance Reports'),
              centerTitle: false,
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
            if (_isLoading)
              SliverToBoxAdapter(child: _buildReportsSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                    Icon(Icons.error_outline,
                        size: 64.sp, color: Colors.grey.shade400),
                    SizedBox(height: 16.h),
                    Text(_error!,
                        style: TextStyle(color: Colors.grey.shade500)),
                    SizedBox(height: 16.h),
                    ElevatedButton.icon(
                        onPressed: _loadReports,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry')),
                  ])))
            else if (_reports.isEmpty)
              SliverFillRemaining(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                    Icon(Icons.analytics_outlined,
                        size: 64.sp, color: Colors.grey.shade400),
                    SizedBox(height: 16.h),
                    Text('No reports yet',
                        style: TextStyle(
                            fontSize: 16.sp, color: Colors.grey.shade500)),
                    SizedBox(height: 8.h),
                    Text('Reports appear after ending sessions',
                        style: TextStyle(
                            fontSize: 13.sp, color: Colors.grey.shade400),
                        textAlign: TextAlign.center),
                  ])))
            else ...[
              SliverToBoxAdapter(child: _buildFilterBar(isDark)),
              if (_filteredReports.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60.h),
                    child: Column(children: [
                      Icon(Icons.search_off,
                          size: 56.sp, color: Colors.grey.shade400),
                      SizedBox(height: 12.h),
                      Text('No reports match the filters',
                          style: TextStyle(
                              fontSize: 14.sp, color: Colors.grey.shade500)),
                    ]),
                  ),
                )
              else
                SliverList(
                    delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    child:
                        _buildReportCard(_filteredReports[index], isDark, index),
                  ),
                  childCount: _filteredReports.length,
                )),
            ],
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
    );
  }

  // ============================================
  // Loading skeleton — mirrors the real report card layout
  // ============================================
  Widget _buildReportsSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppSkeleton(
      enabled: true,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: _skeletonReportCard(isDark),
        ),
      ),
    );
  }

  Widget _skeletonBox(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(6.r),
        ),
      );

  Widget _skeletonReportCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200),
      ),
      child: Column(children: [
        // Header: subject name + code, rate badge
        Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(150.w, 15.h),
                  SizedBox(height: 7.h),
                  _skeletonBox(80.w, 11.h),
                ],
              ),
            ),
            Container(
              width: 54.w,
              height: 46.h,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
          ]),
        ),
        // Mini stats row (Date • Start • Duration • Present)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (_) => Column(children: [
                Container(
                  width: 22.w,
                  height: 22.w,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(height: 6.h),
                _skeletonBox(38.w, 10.h),
                SizedBox(height: 4.h),
                _skeletonBox(28.w, 8.h),
              ]),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        // Action buttons (View Details • PDF)
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          child: Row(children: [
            Expanded(child: _skeletonBox(double.infinity, 42.h)),
            SizedBox(width: 12.w),
            _skeletonBox(72.w, 42.h),
          ]),
        ),
      ]),
    );
  }

  // ============================================
  // Filter bar (search) — Subject • Level • Date
  // ============================================
  Widget _buildFilterBar(bool isDark) {
    final subjects = _subjectOptions;
    final levels = _levelOptions;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterPill(
            icon: Icons.menu_book_outlined,
            label: _filterSubject ?? 'All Subjects',
            active: _filterSubject != null,
            isDark: isDark,
            onTap: () => _pickFromList(
              title: 'Subject',
              options: ['All Subjects', ...subjects],
              onSelected: (v) => setState(
                  () => _filterSubject = v == 'All Subjects' ? null : v),
            ),
          ),
          SizedBox(width: 8.w),
          _filterPill(
            icon: Icons.layers_outlined,
            label: _filterLevel == null ? 'All Levels' : 'Level $_filterLevel',
            active: _filterLevel != null,
            isDark: isDark,
            onTap: () => _pickFromList(
              title: 'Level',
              options: ['All Levels', ...levels.map((l) => 'Level $l')],
              onSelected: (v) => setState(() => _filterLevel = v == 'All Levels'
                  ? null
                  : int.tryParse(v.replaceAll('Level ', ''))),
            ),
          ),
          SizedBox(width: 8.w),
          _filterPill(
            icon: Icons.calendar_today,
            label: _filterDate == null
                ? 'Any Date'
                : '${_filterDate!.day}/${_filterDate!.month}/${_filterDate!.year}',
            active: _filterDate != null,
            isDark: isDark,
            onTap: _pickDate,
          ),
          if (_hasActiveFilter) ...[
            SizedBox(width: 8.w),
            _filterPill(
              icon: Icons.close,
              label: 'Clear',
              active: true,
              isDark: isDark,
              onTap: () => setState(() {
                _filterSubject = null;
                _filterLevel = null;
                _filterDate = null;
              }),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _filterPill({
    required IconData icon,
    required String label,
    required bool active,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).primaryColor;
    final bg = active
        ? primary.withValues(alpha: 0.15)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100);
    final fg = active
        ? primary
        : (isDark ? Colors.white70 : const Color(0xFF475569));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
              color: active
                  ? primary.withValues(alpha: 0.4)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade300)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14.sp, color: fg),
          SizedBox(width: 6.w),
          Text(label,
              style: TextStyle(
                  fontSize: 12.sp, fontWeight: FontWeight.w600, color: fg)),
          if (icon != Icons.close) ...[
            SizedBox(width: 4.w),
            Icon(Icons.keyboard_arrow_down, size: 15.sp, color: fg),
          ],
        ]),
      ),
    );
  }

  void _pickFromList({
    required String title,
    required List<String> options,
    required void Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: EdgeInsets.symmetric(vertical: 10.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                  color: Colors.grey.shade500,
                  borderRadius: BorderRadius.circular(4.r))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15.sp)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map((o) => ListTile(
                        title: Text(o, style: TextStyle(fontSize: 13.sp)),
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(o);
                        },
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 8.h),
        ]),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _filterDate = picked);
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark, int index) {
    final subjectName =
        report['subjectName'] ?? report['subject_name'] ?? 'Unknown';
    final subjectCode = report['subjectCode'] ?? report['subject_code'] ?? '';
    final startTime = report['startTime'] ??
        report['start_time'] ??
        report['startedAt'] ??
        '';
    final endTime = report['endTime'] ??
        report['end_time'] ??
        report['endedAt'] ??
        report['ended_at'] ??
        report['createdAt'] ??
        report['created_at'] ??
        '';

    final dateField = (report['createdAt'] ??
            report['created_at'] ??
            report['date'] ??
            (startTime.toString().isNotEmpty ? startTime : '') ??
            '')
        .toString();
    final students = report['students'] as List? ?? [];
    final totalStudents = report['totalStudents'] ??
        report['total_students'] ??
        report['enrolled'] ??
        students.length;
    final presentCount = report['presentCount'] ??
        report['present_count'] ??
        report['present'] ??
        students.where((s) => s['status'] == 'confirmed').length;
    final rate = totalStudents > 0 ? (presentCount / totalStudents * 100) : 0.0;

    final formattedDate = _fmtDate(dateField.toString());
    final formattedStart = _fmtTime12(startTime.toString());
    final durationText =
        _calculateDuration(startTime.toString(), endTime.toString());
    final presentText = '$presentCount/$totalStudents';

    final rateColor = rate >= 75
        ? const Color(0xFF10B981)
        : rate >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(subjectName,
                      style: TextStyle(
                          fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  if (subjectCode.isNotEmpty)
                    Text(subjectCode,
                        style: TextStyle(
                            fontSize: 12.sp, color: Theme.of(context).hintColor)),
                ])),
            IconButton(
              onPressed:
                  _isDeleting ? null : () => _deleteReport(report, index),
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red.shade400,
                size: 22.sp,
              ),
              tooltip: 'Delete Report',
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                  color: rateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14.r)),
              child: Column(children: [
                Text('${rate.toInt()}%',
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: rateColor)),
                Text('Rate', style: TextStyle(fontSize: 9.sp, color: rateColor)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(children: [
            _miniStat(Icons.calendar_today, formattedDate, 'Date'),
            _miniStat(Icons.play_arrow, formattedStart, 'Start'),
            _miniStat(Icons.access_time,
                durationText.isNotEmpty ? durationText : '--', 'Duration'),
            _miniStat(Icons.people, presentText, 'Present'),
          ]),
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          child: Builder(builder: (ctx) {
            const canView = true;
            const canExport = true;

            return Row(
              children: [
                if (canView)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDetails(report),
                      icon: Icon(Icons.visibility, size: 18.sp),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r)),
                        side: BorderSide(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                if (canView && canExport) SizedBox(width: 12.w),
                if (canExport)
                  OutlinedButton.icon(
                    onPressed: () => _downloadPdf(report),
                    icon: Icon(Icons.picture_as_pdf, size: 18.sp),
                    label: const Text('PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: 12.h, horizontal: 16.w),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                      side:
                          BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                    ),
                  ),
              ],
            );
          }),
        ),
      ]),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Expanded(
        child: Column(children: [
      Icon(icon, size: 14.sp, color: Theme.of(context).hintColor),
      SizedBox(height: 4.h),
      Text(value,
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
      Text(label,
          style: TextStyle(fontSize: 9.sp, color: Theme.of(context).hintColor)),
    ]));
  }

  // ============================================
  // Detail Sheet
  // ============================================
  void _showDetails(Map<String, dynamic> report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName =
        report['subjectName'] ?? report['subject_name'] ?? 'Unknown';
    final students =
        (report['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final startTime = (report['startTime'] ??
            report['start_time'] ??
            report['startedAt'] ??
            '')
        .toString();
    final endTime = (report['endTime'] ??
            report['end_time'] ??
            report['endedAt'] ??
            report['ended_at'] ??
            report['createdAt'] ??
            report['created_at'] ??
            '')
        .toString();

    final confirmed =
        students.where((s) => s['status'] == 'confirmed').toList();
    final pending = students.where((s) => s['status'] == 'pending').toList();
    final absent = students
        .where((s) => s['status'] != 'confirmed' && s['status'] != 'pending')
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24.r))),
        child: Column(children: [
          Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 48.w,
              height: 4.h,
              decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(4.r))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(subjectName,
                        style: TextStyle(
                            fontSize: 20.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Text(
                        startTime.isNotEmpty
                            ? _fmtFull12(startTime)
                            : _fmtFull12(endTime),
                        style: TextStyle(
                            fontSize: 12.sp, color: Theme.of(context).hintColor)),
                    if (endTime.isNotEmpty)
                      Text('Ended: ${_fmtTime12(endTime)}',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Theme.of(context).hintColor)),
                    if (startTime.isNotEmpty && endTime.isNotEmpty)
                      Text(
                          'Duration: ${_calculateDuration(startTime, endTime)}',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Theme.of(context).hintColor)),
                  ])),
              IconButton(
                onPressed: () => _downloadPdf(report),
                icon: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(Icons.picture_as_pdf,
                      color: Colors.red, size: 22.sp),
                ),
              ),
            ]),
          ),
          SizedBox(height: 12.h),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(children: [
                _summaryChip(
                    'Confirmed', confirmed.length, const Color(0xFF10B981)),
                SizedBox(width: 8.w),
                _summaryChip(
                    'Pending', pending.length, const Color(0xFFF59E0B)),
                SizedBox(width: 8.w),
                _summaryChip('Absent', absent.length, const Color(0xFFEF4444)),
              ])),
          SizedBox(height: 16.h),
          const Divider(height: 1),
          Expanded(
            child: students.isEmpty
                ? const Center(
                    child: Text('No student data',
                        style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.builder(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    itemCount: students.length,
                    itemBuilder: (_, i) => _studentRow(students[i], isDark),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) => Expanded(
          child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r)),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 20.sp, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10.sp, color: color)),
        ]),
      ));

  Widget _studentRow(Map<String, dynamic> student, bool isDark) {
    final name = student['student_name'] ??
        student['studentName'] ??
        student['name'] ??
        'Unknown';
    final sid = student['student_id_number'] ??
        student['studentIdNumber'] ??
        student['studentId'] ??
        student['student_id'] ??
        '';
    final status = student['status'] ?? 'absent';
    final confirmedAt =
        student['confirmed_at'] ?? student['qr_scanned_at'] ?? '';
    final faceAt = student['face_detected_at'] ?? student['created_at'] ?? '';
    final duration = student['attendance_duration'] ?? '';

    Color col;
    IconData icon;
    String lab;
    switch (status) {
      case 'confirmed':
        col = const Color(0xFF10B981);
        icon = Icons.check_circle;
        lab = 'Present';
        break;
      case 'pending':
        col = const Color(0xFFF59E0B);
        icon = Icons.access_time;
        lab = 'Pending';
        break;
      default:
        col = const Color(0xFFEF4444);
        icon = Icons.cancel;
        lab = 'Absent';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border(left: BorderSide(color: col, width: 3)),
      ),
      child: Row(children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
              color: col.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r)),
          child: Center(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: col))),
        ),
        SizedBox(width: 12.w),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp)),
          if (sid.toString().isNotEmpty)
            Text(sid.toString(),
                style: TextStyle(
                    fontSize: 10.sp, color: Theme.of(context).hintColor)),
          if (faceAt.isNotEmpty)
            Text('Face: ${_fmtTime12(faceAt)}',
                style: TextStyle(fontSize: 10.sp, color: col)),
          if (confirmedAt.isNotEmpty)
            Text('QR: ${_fmtTime12(confirmedAt)}',
                style: TextStyle(fontSize: 10.sp, color: col)),
          if (duration.isNotEmpty)
            Text('Duration: $duration',
                style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor)),
        ])),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
              color: col.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20.r)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14.sp, color: col),
            SizedBox(width: 4.w),
            Text(lab,
                style: TextStyle(
                    fontSize: 11.sp, fontWeight: FontWeight.w600, color: col)),
          ]),
        ),
      ]),
    );
  }

  // ============================================
  // PDF Download
  // ============================================
  Future<void> _downloadPdf(Map<String, dynamic> report) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          SizedBox(
              width: 20.w,
              height: 20.w,
              child: const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 16.w),
          const Text('Generating PDF...'),
        ]),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 3),
      ),
    );

    Map<String, dynamic> fullReport = Map.from(report);
    if ((fullReport['students'] as List?)?.isEmpty ?? true) {
      final auth = context.read<AuthCubit>().state;
      final sessionId = report['sessionId'] ?? '';
      if (sessionId.isNotEmpty && auth.token != null) {
        final result = await _attendanceRepo.getReportBySession(
          sessionId: sessionId,
          token: auth.token!,
        );
        final fetched = result.valueOrNull;
        if (fetched != null) fullReport = fetched;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    await PdfReportService.generateAndOpen(context, fullReport);
  }

  // ============================================
  // Time Formatting — 12-hour + local timezone
  // ============================================
  String _fmtTime12(String iso) {
    if (iso.isEmpty) return '';
    final dt = _parseFlexibleTime(iso);
    if (dt == null) return iso;
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  DateTime? _parseFlexibleTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.toLocal();

    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?$')
        .firstMatch(s);
    if (m == null) return null;

    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final second = int.parse(m.group(3) ?? '0');
    final ampm = m.group(4)?.toUpperCase();
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59 || second > 59) return null;

    return DateTime(2000, 1, 1, hour, minute, second);
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtFull12(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return iso;
    }
  }

  String _calculateDuration(String startIso, String endIso) {
    final start = _parseFlexibleTime(startIso);
    final end = _parseFlexibleTime(endIso);
    if (start == null || end == null) return '';

    DateTime tod(DateTime d) =>
        DateTime(2000, 1, 1, d.hour, d.minute, d.second);
    var duration = tod(end).difference(tod(start));

    if (duration.isNegative) duration += const Duration(days: 1);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}
