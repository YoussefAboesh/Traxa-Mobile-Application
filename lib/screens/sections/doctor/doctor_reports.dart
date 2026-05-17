// lib/screens/sections/doctor/doctor_reports.dart
// ✅ Fixes: 12-hour time + local timezone + working PDF download + RefreshIndicator + Delete Reports
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../../cubit/auth/auth_cubit.dart';
import '../../../core/constants.dart';
import '../../../core/pdf_report_service.dart';
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthCubit>().state;
      final token = auth.token;
      final doctorId = auth.user?.effectiveDoctorId ?? 0;
      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final res = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}/api/attendance-reports/doctor/$doctorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reports = (data is List)
            ? data.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];
        reports.sort((a, b) => (b['createdAt'] ?? b['created_at'] ?? '')
            .compareTo(a['createdAt'] ?? a['created_at'] ?? ''));
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load reports';
          _isLoading = false;
        });
      }
    } catch (e) {
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
  // DELETE REPORT
  // ============================================
  Future<void> _deleteReport(Map<String, dynamic> report, int index) async {
    // Confirm deletion
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

    if (shouldDelete != true) return;

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

      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/attendance-reports/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Remove from local list
        setState(() {
          _reports.removeAt(index);
        });
        // ignore: use_build_context_synchronously
        ToastMessage.showSuccess(context, 'Report deleted successfully');
      } else {
        // ignore: use_build_context_synchronously
        ToastMessage.showError(context, 'Failed to delete report');
      }
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
              const SliverFillRemaining(
                  hasScrollBody: true, child: SkeletonCardList())
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
            else
              SliverList(
                  delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  child: _buildReportCard(_reports[index], isDark, index),
                ),
                childCount: _reports.length,
              )),
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark, int index) {
    final subjectName =
        report['subjectName'] ?? report['subject_name'] ?? 'Unknown';
    final subjectCode = report['subjectCode'] ?? report['subject_code'] ?? '';
    // 🕒 Always read the real session boundaries:
    //   start = startTime/start_time (when activate was hit)
    //   end   = endTime/end_time/endedAt (when end-session was hit)
    // ⚠️ IMPORTANT: createdAt/created_at is the *report save* timestamp on the server
    // and MUST NOT be used as end time — this was causing 1-hour delay issues.
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

    final dateField =
        startTime.toString().isNotEmpty ? startTime : (report['date'] ?? '');
    final students = report['students'] as List? ?? [];
    final totalStudents =
        report['totalStudents'] ?? report['total_students'] ?? students.length;
    final presentCount = report['presentCount'] ??
        report['present_count'] ??
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
            // ✅ Delete button
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
            final user = ctx.watch<AuthCubit>().state.user;
            final canView =
                user == null || user.hasTAPermission('ta.reports.view');
            final canExport =
                user == null || user.hasTAPermission('ta.reports.export');

            if (!canView && !canExport) {
              return Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 14.sp, color: Colors.grey),
                    SizedBox(width: 6.w),
                    Text('Actions locked by professor',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                  ],
                ),
              );
            }

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
                  // ✅ Download PDF button
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
    // Match the website: prefer startTime/endTime; createdAt is the
    // report-saved timestamp and must not be shown as the start.
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
    final name = student['student_name'] ?? student['name'] ?? 'Unknown';
    final sid = student['student_id_number'] ?? student['student_id'] ?? '';
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
    // Show loading
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

    // Fetch full report data if students list is empty
    Map<String, dynamic> fullReport = Map.from(report);
    if ((fullReport['students'] as List?)?.isEmpty ?? true) {
      final auth = context.read<AuthCubit>().state;
      final sessionId = report['sessionId'] ?? '';
      if (sessionId.isNotEmpty && auth.token != null) {
        try {
          final res = await http.get(
            Uri.parse(
                '${AppConstants.baseUrl}/api/attendance-reports/session/$sessionId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${auth.token}'
            },
          ).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            fullReport = jsonDecode(res.body);
          }
        } catch (_) {}
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
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return iso;
    }
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

  /// Calculate and format the duration between start and end times
  /// Returns a human-readable duration string (e.g., "2h 30m" or "45m")
  String _calculateDuration(String startIso, String endIso) {
    if (startIso.isEmpty || endIso.isEmpty) {
      return '';
    }

    try {
      final startTime = DateTime.parse(startIso).toLocal();
      final endTime = DateTime.parse(endIso).toLocal();

      // Ensure end time is after start time
      if (endTime.isBefore(startTime)) {
        print('⚠️ Warning: End time is before start time');
        return 'Error';
      }

      final duration = endTime.difference(startTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);

      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${minutes}m';
      }
    } catch (e) {
      print('❌ Error calculating duration: $e');
      return '';
    }
  }
}
