// lib/screens/sections/doctor/doctor_ta_management.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/teaching_assistant.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/toast_message.dart';
import 'doctor_ta_permissions.dart';

class DoctorTAManagement extends StatefulWidget {
  const DoctorTAManagement({super.key});

  @override
  State<DoctorTAManagement> createState() => _DoctorTAManagementState();
}

class _DoctorTAManagementState extends State<DoctorTAManagement> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService.instance.taPermissionsStream.listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final doctor = context.read<AuthCubit>().state.user;
    if (doctor == null) return;
    setState(() => _loading = true);
    await context.read<DataCubit>().fetchTAsForDoctor(doctor.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tas = context.watch<DataCubit>().state.teachingAssistants;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('TA Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : tas.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.people_outline,
                          size: 64,
                          color: isDark
                              ? Colors.white24
                              : Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No teaching assistants assigned',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tas.length,
                    itemBuilder: (_, i) => _buildTACard(tas[i], isDark),
                  ),
      ),
    );
  }

  Widget _buildTACard(TeachingAssistant ta, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CustomCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ta.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (ta.email != null && ta.email!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.mail_outline,
                                size: 13,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ta.email!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            '@${ta.username}  •  ID: ${ta.id}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              height: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user,
                          size: 12, color: Color(0xFF0EA5E9)),
                      SizedBox(width: 4),
                      Text(
                        'Your Assistant',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorTAPermissions(ta: ta),
                      ),
                    );
                    if (saved == true && mounted) {
                      ToastMessage.showSuccess(
                          context, 'Permissions updated');
                      _load();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Permissions',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
