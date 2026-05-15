// lib/screens/sections/doctor/doctor_ta_management.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:traxa_mobile/core/theme.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/subject.dart';
import '../../../models/teaching_assistant.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/toast_message.dart';
import '../../../core/api_service.dart';

class DoctorTAManagement extends StatefulWidget {
  const DoctorTAManagement({super.key});

  @override
  State<DoctorTAManagement> createState() => _DoctorTAManagementState();
}

class _DoctorTAManagementState extends State<DoctorTAManagement> {
  bool _loading = true;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _wsSub = WebSocketService.instance.taPermissionsStream.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await context.read<DataCubit>().loadAllData();
    if (mounted) {
      // Debug: confirm TAs are loaded
      final tas = context.read<DataCubit>().state.teachingAssistants;
      print('🔍 TAs count: ${tas.length}');
      for (final ta in tas) {
        print('  TA: id=${ta.id} name=${ta.name} assignedSubjects=${ta.assignedSubjectIds}');
      }
      setState(() => _loading = false);
    }
  }

  /// P0 → subject.taId + subject.taName مباشرة من backend
  /// P1 → subject.taId يطابق ta.id في tas list
  /// P2 → assignedSubjectIds
  TeachingAssistant? _resolveTA(Subject subject, List<TeachingAssistant> tas) {
    // P0: الـ subject عنده ta_id + ta_name من /api/subjects مباشرة
    if (subject.taId != null &&
        subject.taName != null &&
        subject.taName!.isNotEmpty) {
      return TeachingAssistant(
        id: subject.taId!,
        name: subject.taName!,
        username: subject.taName!,
        assignedSubjectIds: [subject.id],
      );
    }
    // P1
    if (subject.taId != null) {
      final m = tas.where((t) => t.id == subject.taId).toList();
      if (m.isNotEmpty) return m.first;
    }
    // P2
    final m2 = tas.where((t) => t.assignedSubjectIds.contains(subject.id)).toList();
    if (m2.isNotEmpty) return m2.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = context.isDarkMode;
    final user = authState.user;
    final currentSemester = dataState.currentSemester;

    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('User not found')));
    }

    final doctorId = user.effectiveDoctorId;
    final subjects = (currentSemester > 0
            ? dataState.allSubjects.where(
                (s) => s.doctorId == doctorId && s.semester == currentSemester)
            : dataState.allSubjects.where((s) => s.doctorId == doctorId))
        .toList();
    final tas = dataState.teachingAssistants;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(isDark, currentSemester),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: subjects.isEmpty
                          ? _buildEmpty(isDark, currentSemester)
                          : _buildTable(subjects, tas, isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ─────────────────────────────────────────

  Widget _buildTopBar(bool isDark, int currentSemester) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color:
                      isDark ? Colors.white70 : const Color(0xFF1E293B)),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subjects & Teaching Assistants',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Manage TA assignments and permissions for each subject',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF8B5CF6).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF8B5CF6)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Semester $currentSemester',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty ───────────────────────────────────────────

  Widget _buildEmpty(bool isDark, int semester) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.assignment_late_outlined,
            size: 64,
            color:
                isDark ? Colors.white24 : Colors.grey.shade300),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'No subjects found for Semester $semester',
            style: TextStyle(
              fontSize: 14,
              color:
                  isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Table ───────────────────────────────────────────

  Widget _buildTable(
    List<Subject> subjects,
    List<TeachingAssistant> tas,
    bool isDark,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildTableHeader(isDark),
              ...subjects.asMap().entries.map(
                    (e) => _buildRow(
                      e.value,
                      tas,
                      isDark,
                      isLast: e.key == subjects.length - 1,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('SUBJECT',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 1)),
          ),
          SizedBox(
            width: 86,
            child: Text('ASSIGNED TA',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 1)),
          ),
          SizedBox(
            width: 106,
            child: Text('TA PERMISSIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    Subject subject,
    List<TeachingAssistant> tas,
    bool isDark, {
    required bool isLast,
  }) {
    final assignedTA = _resolveTA(subject, tas);
    final hasTA = assignedTA != null;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Subject
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (subject.code != null)
                      _MiniChip(
                          label: subject.code!,
                          color: const Color(0xFF8B5CF6)),
                    _MiniChip(
                        label: 'Level ${subject.level}',
                        color: const Color(0xFF0EA5E9)),
                    if (subject.department != null)
                      _MiniChip(
                          label: subject.department!,
                          color: const Color(0xFF10B981)),
                    _MiniChip(
                        label: 'Semester ${subject.semester}',
                        color: Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          // Assigned TA
          SizedBox(
            width: 86,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: hasTA
                      ? const Color(0xFF10B981)
                          .withValues(alpha: 0.13)
                      : Colors.grey.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasTA
                          ? Icons.person_rounded
                          : Icons.person_off_rounded,
                      size: 12,
                      color: hasTA
                          ? const Color(0xFF10B981)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        hasTA ? assignedTA.name : 'None',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: hasTA
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Set Permissions
          SizedBox(
            width: 106,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _openSheet(subject, assignedTA, isDark),
                icon: const Icon(Icons.tune_rounded, size: 12),
                label: const Text('Set Permissions',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSheet(Subject subject, TeachingAssistant? assignedTA,
      bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<AuthCubit>()),
          BlocProvider.value(value: context.read<DataCubit>()),
        ],
        child: _PermissionsSheet(
          subject: subject,
          assignedTA: assignedTA,
          isDark: isDark,
          onSaved: _loadData,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PERMISSIONS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _PermissionsSheet extends StatefulWidget {
  final Subject subject;
  final TeachingAssistant? assignedTA;
  final bool isDark;
  final VoidCallback onSaved;

  const _PermissionsSheet({
    required this.subject,
    required this.assignedTA,
    required this.isDark,
    required this.onSaved,
  });

  @override
  State<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<_PermissionsSheet> {
  bool _canActivateSession = true;
  bool _canManageGrades = true;
  bool _isLoading = true;
  bool _isSaving = false;
  StreamSubscription? _wsSub;

  String? get _token => ApiService.getToken();

  @override
  void initState() {
    super.initState();
    _load();
    _wsSub = WebSocketService.instance.taPermissionsStream.listen((data) {
      final taId = data['taId'] ?? data['ta_id'];
      final subjectId = data['subjectId'] ?? data['subject_id'];
      if (taId == widget.assignedTA?.id &&
          subjectId == widget.subject.id &&
          mounted &&
          !_isSaving) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (widget.assignedTA == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final resp = await ApiService.getTASubjectPermissions(
        widget.assignedTA!.id,
        widget.subject.id,
        token,
      );
      if (mounted) {
        setState(() {
          _canActivateSession = resp['can_activate_session'] ?? true;
          _canManageGrades = resp['can_manage_grades'] ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (widget.assignedTA == null) {
      ToastMessage.showError(context, 'No TA assigned to this subject');
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      ToastMessage.showError(
          context, 'Session expired, please login again');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.updateTASubjectPermissions(
        taId: widget.assignedTA!.id,
        subjectId: widget.subject.id,
        permissions: {
          'can_activate_session': _canActivateSession,
          'can_manage_grades': _canManageGrades,
        },
        token: token,
      );
      if (result['success'] == true) {
        ToastMessage.showSuccess(context, 'Permissions saved successfully');
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        ToastMessage.showError(
            context, result['error'] ?? 'Failed to save permissions');
      }
    } catch (e) {
      ToastMessage.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1E293B);
    final textSub =
        isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.grey.shade200;
    final hasTA = widget.assignedTA != null;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 22, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TA Permissions',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary)),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 12, color: textSub),
                          children: [
                            const TextSpan(text: 'TA: '),
                            TextSpan(
                              text: hasTA
                                  ? widget.assignedTA!.name
                                  : 'None',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: hasTA
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Subject pill
                Container(
                  constraints:
                      const BoxConstraints(maxWidth: 100),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6)
                        .withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.subject.name,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B5CF6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 17, color: textSub),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Info card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.school_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'TA',
                    value: hasTA
                        ? widget.assignedTA!.name
                        : 'None',
                    valueColor:
                        hasTA ? const Color(0xFF10B981) : Colors.grey,
                    textPrimary: textPrimary,
                    textSub: textSub,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF0EA5E9),
                    label: 'Subject',
                    value: widget.subject.name,
                    valueColor: textPrimary,
                    textPrimary: textPrimary,
                    textSub: textSub,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Amber banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFD97706)
                        .withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD97706)),
                        children: [
                          TextSpan(text: 'By default everything is '),
                          TextSpan(
                              text: 'visible',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                          TextSpan(text: '. Check to '),
                          TextSpan(
                              text: 'hide',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                          TextSpan(text: ' from this TA.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tiles
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (!hasTA)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          Colors.orange.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No TA assigned to this subject yet.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade300),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _PermTile(
              isDark: isDark,
              icon: Icons.play_circle_outline_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Hide Activate/End Session',
              subtitle:
                  'Hides the Activate Session button from My Sections for this subject',
              checked: !_canActivateSession,
              onTap: _isSaving
                  ? null
                  : () => setState(() =>
                      _canActivateSession = !_canActivateSession),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1, color: dividerColor),
            ),
            _PermTile(
              isDark: isDark,
              icon: Icons.school_outlined,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Hide Grades Section',
              subtitle:
                  'Hides the grades section for this subject from this TA',
              checked: !_canManageGrades,
              onTap: _isSaving
                  ? null
                  : () => setState(
                      () => _canManageGrades = !_canManageGrades),
            ),
          ],

          const SizedBox(height: 20),

          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isSaving || !hasTA) ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded,
                            size: 16),
                    label: const Text('Save',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white60
                          : const Color(0xFF64748B),
                      side: BorderSide(
                          color: isDark
                              ? Colors.white
                                  .withValues(alpha: 0.15)
                              : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final Color textPrimary;
  final Color textSub;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.textPrimary,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(fontSize: 13, color: textSub)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _PermTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool checked;
  final VoidCallback? onTap;

  const _PermTile({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1E293B);
    final textSub =
        isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: textSub)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked
                    ? const Color(0xFF8B5CF6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked
                      ? const Color(0xFF8B5CF6)
                      : (isDark
                          ? const Color(0xFF475569)
                          : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
