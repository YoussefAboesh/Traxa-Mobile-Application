// lib/screens/sections/doctor/doctor_reports.dart
// ✅ Fixes: 12-hour time + local timezone + working PDF download
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../cubit/auth/auth_cubit.dart';
import '../../../core/constants.dart';
import '../../../core/pdf_report_service.dart';

class DoctorReports extends StatefulWidget {
  const DoctorReports({super.key});

  @override
  State<DoctorReports> createState() => _DoctorReportsState();
}

class _DoctorReportsState extends State<DoctorReports> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = context.read<AuthCubit>().state;
      final token = auth.token;
      final doctorId = auth.user?.id ?? 0;
      if (token == null) { setState(() { _error = 'Not authenticated'; _isLoading = false; }); return; }

      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/attendance-reports/doctor/$doctorId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reports = (data is List) ? data.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
        reports.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
        setState(() { _reports = reports; _isLoading = false; });
      } else {
        setState(() { _error = 'Failed to load reports'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(title: const Text('Attendance Reports'), centerTitle: false, floating: true, backgroundColor: Theme.of(context).scaffoldBackgroundColor, actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
            ]),

            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: _loadReports, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ])))
            else if (_reports.isEmpty)
              SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No reports yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('Reports appear after ending sessions', style: TextStyle(fontSize: 13, color: Colors.grey.shade400), textAlign: TextAlign.center),
              ])))
            else
              SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: _buildReportCard(_reports[i], isDark)),
                childCount: _reports.length,
              )),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark) {
    final subjectName = report['subjectName'] ?? report['subject_name'] ?? 'Unknown';
    final subjectCode = report['subjectCode'] ?? report['subject_code'] ?? '';
    final createdAt = report['createdAt'] ?? '';
    final endedAt = report['endedAt'] ?? '';
    final students = report['students'] as List? ?? [];
    final totalStudents = report['totalStudents'] ?? students.length;
    final presentCount = report['presentCount'] ?? students.where((s) => s['status'] == 'confirmed').length;
    final rate = totalStudents > 0 ? (presentCount / totalStudents * 100) : 0.0;

    final formattedDate = _fmtDate(createdAt);
    final formattedStart = _fmtTime12(createdAt);
    final formattedEnd = _fmtTime12(endedAt);
    final presentText = '$presentCount/$totalStudents';

    final rateColor = rate >= 75 ? const Color(0xFF10B981) : rate >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subjectName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (subjectCode.isNotEmpty) Text(subjectCode, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: rateColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('${rate.toInt()}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: rateColor)),
                Text('Rate', style: TextStyle(fontSize: 9, color: rateColor)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _miniStat(Icons.calendar_today, formattedDate, 'Date'),
            _miniStat(Icons.play_arrow, formattedStart, 'Start'),
            _miniStat(Icons.stop, formattedEnd.isNotEmpty ? formattedEnd : '--', 'End'),
            _miniStat(Icons.people, presentText, 'Present'),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDetails(report),
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Expanded(child: Column(children: [
      Icon(icon, size: 14, color: Theme.of(context).hintColor),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(fontSize: 9, color: Theme.of(context).hintColor)),
    ]));
  }

  // ============================================
  // Detail Sheet
  // ============================================
  void _showDetails(Map<String, dynamic> report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName = report['subjectName'] ?? 'Unknown';
    final students = (report['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final createdAt = report['createdAt'] ?? '';
    final endedAt = report['endedAt'] ?? '';

    final confirmed = students.where((s) => s['status'] == 'confirmed').toList();
    final pending = students.where((s) => s['status'] == 'pending').toList();
    final absent = students.where((s) => s['status'] != 'confirmed' && s['status'] != 'pending').toList();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subjectName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_fmtFull12(createdAt), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                if (endedAt.isNotEmpty) Text('Ended: ${_fmtTime12(endedAt)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ])),
              // ✅ PDF Download — بيشتغل فعلاً
              IconButton(
                onPressed: () => _downloadPdf(report),
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
            _summaryChip('Confirmed', confirmed.length, const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _summaryChip('Pending', pending.length, const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _summaryChip('Absent', absent.length, const Color(0xFFEF4444)),
          ])),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('No student data', style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: students.length,
                    itemBuilder: (_, i) => _studentRow(students[i], isDark),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color)),
    ]),
  ));

  Widget _studentRow(Map<String, dynamic> student, bool isDark) {
    final name = student['student_name'] ?? student['name'] ?? 'Unknown';
    final sid = student['student_id_number'] ?? student['student_id'] ?? '';
    final status = student['status'] ?? 'absent';
    final confirmedAt = student['confirmed_at'] ?? student['qr_scanned_at'] ?? '';
    final faceAt = student['face_detected_at'] ?? student['created_at'] ?? '';
    final duration = student['attendance_duration'] ?? '';

    Color col; IconData icon; String lab;
    switch (status) {
      case 'confirmed': col = const Color(0xFF10B981); icon = Icons.check_circle; lab = 'Present'; break;
      case 'pending': col = const Color(0xFFF59E0B); icon = Icons.access_time; lab = 'Pending'; break;
      default: col = const Color(0xFFEF4444); icon = Icons.cancel; lab = 'Absent';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: col, width: 3)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold, color: col))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (sid.toString().isNotEmpty) Text(sid.toString(), style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
          if (faceAt.isNotEmpty) Text('Face: ${_fmtTime12(faceAt)}', style: TextStyle(fontSize: 10, color: col)),
          if (confirmedAt.isNotEmpty) Text('QR: ${_fmtTime12(confirmedAt)}', style: TextStyle(fontSize: 10, color: col)),
          if (duration.isNotEmpty) Text('Duration: $duration', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: col),
            const SizedBox(width: 4),
            Text(lab, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col)),
          ]),
        ),
      ]),
    );
  }

  // ============================================
  // PDF Download — ✅ شغال فعلاً
  // ============================================
  Future<void> _downloadPdf(Map<String, dynamic> report) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 16),
        Text('Generating PDF...'),
      ]),
      backgroundColor: Theme.of(context).primaryColor,
      duration: const Duration(seconds: 3),
    ));

    // إذا مفيش students data في الـ report، جيبها من السيرفر
    Map<String, dynamic> fullReport = Map.from(report);
    if ((fullReport['students'] as List?)?.isEmpty ?? true) {
      final auth = context.read<AuthCubit>().state;
      final sessionId = report['sessionId'] ?? '';
      if (sessionId.isNotEmpty && auth.token != null) {
        try {
          final res = await http.get(
            Uri.parse('${AppConstants.baseUrl}/api/attendance-reports/session/$sessionId'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${auth.token}'},
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
    } catch (_) { return iso; }
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return iso; }
  }

  String _fmtFull12(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) { return iso; }
  }
}
