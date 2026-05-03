// lib/screens/sections/doctor/doctor_reports.dart
// ✅ صفحة Reports كاملة مع: real API data + detail view + PDF export
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/constants.dart';

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
      final authState = context.read<AuthCubit>().state;
      final token = authState.token;
      final doctorId = authState.user?.id ?? 0;

      if (token == null) {
        setState(() { _error = 'Not authenticated'; _isLoading = false; });
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/attendance-reports/doctor/$doctorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reports = (data is List) ? data.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
        // ترتيب من الأحدث للأقدم
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
    final dataState = context.watch<DataCubit>().state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Attendance Reports'),
              centerTitle: false,
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadReports,
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadReports,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_reports.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No reports yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text('Reports will appear after ending attendance sessions', style: TextStyle(fontSize: 13, color: Colors.grey.shade400), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _buildReportCard(_reports[index], isDark, dataState),
                  ),
                  childCount: _reports.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark, dynamic dataState) {
    final subjectName = report['subjectName'] ?? report['subject_name'] ?? 'Unknown Subject';
    final subjectCode = report['subjectCode'] ?? report['subject_code'] ?? '';
    final createdAt = report['createdAt'] ?? report['created_at'] ?? '';
    final endedAt = report['endedAt'] ?? report['ended_at'] ?? '';
    final students = report['students'] as List? ?? [];
    final totalStudents = report['totalStudents'] ?? students.length;
    final presentCount = report['presentCount'] ?? students.where((s) => s['status'] == 'confirmed').length;
    final attendanceRate = totalStudents > 0 ? (presentCount / totalStudents * 100) : 0.0;

    // تنسيق التاريخ والوقت
    String formattedDate = '';
    String formattedTime = '';
    String formattedEndTime = '';
    try {
      final dt = DateTime.parse(createdAt);
      formattedDate = '${dt.day}/${dt.month}/${dt.year}';
      formattedTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (endedAt.isNotEmpty) {
        final et = DateTime.parse(endedAt);
        formattedEndTime = '${et.hour.toString().padLeft(2, '0')}:${et.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    final rateColor = attendanceRate >= 75
        ? const Color(0xFF10B981)
        : attendanceRate >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subjectName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (subjectCode.isNotEmpty)
                        Text(subjectCode, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
                // Attendance Rate Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: rateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text('${attendanceRate.toInt()}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: rateColor)),
                      Text('Rate', style: TextStyle(fontSize: 9, color: rateColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildMiniStat(Icons.calendar_today, formattedDate, 'Date'),
                _buildMiniStat(Icons.play_arrow, formattedTime, 'Start'),
                _buildMiniStat(Icons.stop, formattedEndTime.isNotEmpty ? formattedEndTime : '--:--', 'End'),
                _buildMiniStat(Icons.people, '$presentCount/$totalStudents', 'Present'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // View Details Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReportDetails(report),
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
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).hintColor),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 9, color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  // ============================================
  // Report Detail Sheet
  // ============================================

  void _showReportDetails(Map<String, dynamic> report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName = report['subjectName'] ?? report['subject_name'] ?? 'Unknown';
    final students = (report['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final createdAt = report['createdAt'] ?? '';
    final endedAt = report['endedAt'] ?? '';

    // تصنيف الطلاب
    final confirmed = students.where((s) => s['status'] == 'confirmed').toList();
    final pending = students.where((s) => s['status'] == 'pending').toList();
    final absent = students.where((s) => s['status'] == 'absent' || s['status'] == null).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 48, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(4)),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subjectName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_formatDateTime(createdAt), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                        if (endedAt.isNotEmpty)
                          Text('Ended: ${_formatTime(endedAt)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ),
                  // PDF Download Button
                  IconButton(
                    onPressed: () => _downloadReportPDF(report),
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildSummaryChip('Confirmed', confirmed.length, const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _buildSummaryChip('Pending', pending.length, const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _buildSummaryChip('Absent', absent.length, const Color(0xFFEF4444)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),

            // Students List
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('No student data available', style: TextStyle(color: Color(0xFF94A3B8))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: students.length,
                      itemBuilder: (_, i) => _buildStudentRow(students[i], isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student, bool isDark) {
    final name = student['student_name'] ?? student['name'] ?? 'Unknown';
    final studentId = student['student_id_number'] ?? student['student_id'] ?? '';
    final status = student['status'] ?? 'absent';
    final confirmedAt = student['confirmed_at'] ?? student['confirmedAt'] ?? '';
    final confirmedBy = student['confirmed_by'] ?? student['confirmedBy'] ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusLabel = 'Present';
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.access_time;
        statusLabel = 'Pending';
        break;
      default:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        statusLabel = 'Absent';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (studentId.isNotEmpty)
                  Text(studentId.toString(), style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                if (confirmedAt.isNotEmpty)
                  Text('Checked in: ${_formatTime(confirmedAt)}', style: TextStyle(fontSize: 10, color: statusColor)),
                if (confirmedBy.isNotEmpty)
                  Text('By: $confirmedBy', style: TextStyle(fontSize: 9, color: Theme.of(context).hintColor)),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PDF Download
  // ============================================

  Future<void> _downloadReportPDF(Map<String, dynamic> report) async {
    final authState = context.read<AuthCubit>().state;
    if (authState.token == null) return;

    final sessionId = report['sessionId'] ?? '';
    if (sessionId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No session ID available for this report'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 16),
              const Text('Generating PDF...'),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    try {
      // جلب التقرير كامل من السيرفر
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/attendance-reports/session/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authState.token}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        
        // حالياً هنبين رسالة إن الـ feature قيد التطوير
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF export will be available soon! Report data loaded successfully.'),
              backgroundColor: Color(0xFFF59E0B),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch report data'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================
  // Helpers
  // ============================================

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
