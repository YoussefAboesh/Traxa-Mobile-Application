// lib/screens/sections/doctor/doctor_ta_permissions.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/teaching_assistant.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/toast_message.dart';

class DoctorTAPermissions extends StatefulWidget {
  final TeachingAssistant ta;
  const DoctorTAPermissions({super.key, required this.ta});

  @override
  State<DoctorTAPermissions> createState() => _DoctorTAPermissionsState();
}

class _DoctorTAPermissionsState extends State<DoctorTAPermissions> {
  static const Map<String, bool> _defaults = {
    'ta.nav.overview': true,
    'ta.nav.subjects': false,
    'ta.nav.lectures': true,
    'ta.nav.attendance': false,
    'ta.nav.reports': true,
    'ta.nav.grading': false,
    'ta.attendance.start': false,
    'ta.attendance.end': false,
    'ta.reports.view': false,
    'ta.reports.export': false,
  };

  late Map<String, bool> _perms;
  // Preserve unknown keys (e.g. ta.grades.view) so we don't drop them on save
  Map<String, dynamic> _extraPerms = {};
  bool _loading = true;
  bool _saving = false;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _perms = Map.from(_defaults);
    _load();
    // Live sync: if the web (or another device) updates this TA's perms,
    // refresh the toggles immediately.
    _wsSub = WebSocketService.instance.taPermissionsStream.listen((data) {
      final taId = data['taId'];
      if (taId == widget.ta.id && mounted && !_saving) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final fetched =
        await context.read<DataCubit>().fetchTAPermissions(widget.ta.id);
    if (!mounted) return;
    setState(() {
      _perms = Map.from(_defaults);
      _extraPerms = {};
      fetched.forEach((k, v) {
        if (_perms.containsKey(k) && v is bool) {
          _perms[k] = v;
        } else {
          _extraPerms[k] = v;
        }
      });
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final payload = <String, dynamic>{..._extraPerms, ..._perms};
    final result = await context
        .read<DataCubit>()
        .updateTAPermissions(widget.ta.id, payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      Navigator.pop(context, true);
      return;
    }

    final status = result['status'];
    final err = result['error']?.toString() ?? 'Unknown error';

    if (status == 401 || status == 403) {
      // Token expired or invalid — JWT lifetime is 8h on the server.
      _showSessionExpiredDialog();
    } else {
      ToastMessage.showError(context, 'Save failed — $err');
    }
  }

  void _showSessionExpiredDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.orange),
            SizedBox(width: 10),
            Text('Session Expired'),
          ],
        ),
        content: const Text(
          'Your login session has expired (8 hour limit). '
          'Please log out and log in again to save permission changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() => _perms = Map.from(_defaults));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('TA Permissions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 16),
                _buildSection(
                  'Navigation Sidebar',
                  Icons.menu_rounded,
                  const Color(0xFF0EA5E9),
                  'Control which sections appear in the sidebar',
                  [
                    _row('ta.nav.overview', 'Overview Dashboard',
                        Icons.pie_chart),
                    _row('ta.nav.subjects', 'Subjects', Icons.menu_book),
                    _row('ta.nav.lectures', 'Lectures',
                        Icons.cast_for_education),
                    _row('ta.nav.attendance', 'Active Sessions',
                        Icons.fingerprint),
                    _row('ta.nav.reports', 'Attendance Reports',
                        Icons.description),
                    _row('ta.nav.grading', 'Student Grades', Icons.school),
                  ],
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSection(
                  'Session Controls',
                  Icons.event_note,
                  const Color(0xFF22C55E),
                  'Control attendance session buttons',
                  [
                    _row('ta.attendance.start', 'Activate Session',
                        Icons.play_arrow),
                    _row('ta.attendance.end', 'End Session', Icons.stop),
                  ],
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildSection(
                  'Reports Controls',
                  Icons.bar_chart,
                  const Color(0xFF8B5CF6),
                  'Control report viewing and exporting',
                  [
                    _row('ta.reports.view', 'View Reports', Icons.visibility),
                    _row('ta.reports.export', 'Export Reports',
                        Icons.download),
                  ],
                  isDark,
                ),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ta.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'ID: ${widget.ta.id}',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color,
      String subtitle, List<Widget> rows, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String key, String label, IconData icon) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.trailing,
      value: _perms[key] ?? false,
      onChanged: (v) => setState(() => _perms[key] = v ?? false),
      title: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
      dense: true,
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: const Text('Save Permissions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _reset,
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
