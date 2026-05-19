// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:traxa_mobile/core/theme.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/subject.dart';
import '../../../models/teaching_assistant.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/toast_message.dart';
import '../../../widgets/app_skeleton.dart';
import '../../../core/api_service.dart';
import '../../../core/logger.dart';

class DoctorTAManagement extends StatefulWidget {
  const DoctorTAManagement({super.key});

  @override
  State<DoctorTAManagement> createState() => _DoctorTAManagementState();
}

class _DoctorTAManagementState extends State<DoctorTAManagement> {
  bool _loading = true;
  StreamSubscription? _wsSub;
  StreamSubscription? _dataSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _wsSub = WebSocketService.instance.taPermissionsStream.listen((_) {
      if (mounted) _loadData();
    });
    _dataSub = WebSocketService.instance.dataChangeStream.listen((data) {
      final entity = data['entity'] as String?;
      if (mounted && (entity == 'subject' || entity == 'teaching-assistant')) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await context.read<DataCubit>().loadAllData();
    if (mounted) {
      final tas = context.read<DataCubit>().state.teachingAssistants;
      logDebug('🔍 TAs count: ${tas.length}');
      for (final ta in tas) {
        logDebug('  TA: id=${ta.id} name=${ta.name} assignedSubjects=${ta.assignedSubjectIds}');
      }
      setState(() => _loading = false);
    }
  }

  TeachingAssistant? _resolveTA(Subject subject, List<TeachingAssistant> tas) {
    final taName = subject.taName?.trim();
    if (subject.taId != null &&
        taName != null &&
        taName.isNotEmpty &&
        taName.toLowerCase() != 'not assigned') {
      final match = tas.where((t) => t.id == subject.taId).toList();
      if (match.isNotEmpty) return match.first;
      return TeachingAssistant(
        id: subject.taId!,
        name: taName,
        username: taName,
        assignedSubjectIds: [subject.id],
      );
    }
    if (subject.taId != null) {
      final m = tas.where((t) => t.id == subject.taId).toList();
      if (m.isNotEmpty) return m.first;
    }
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
                  ? const SkeletonCardList()
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
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 16.w, 12.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
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
                          blurRadius: 6.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16.sp,
                  color:
                      isDark ? Colors.white70 : const Color(0xFF1E293B)),
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.all(9.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Icon(Icons.people_alt_rounded,
                color: Colors.white, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subjects & Teaching Assistants',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Manage TA assignments and permissions for each subject',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF8B5CF6).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: const Color(0xFF8B5CF6)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Semester $currentSemester',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8B5CF6),
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
        SizedBox(height: 120.h),
        Icon(Icons.assignment_late_outlined,
            size: 64.sp,
            color:
                isDark ? Colors.white24 : Colors.grey.shade300),
        SizedBox(height: 14.h),
        Center(
          child: Text(
            'No subjects found for Semester $semester',
            style: TextStyle(
              fontSize: 14.sp,
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
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 28.h),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
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
                    blurRadius: 16.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
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
          EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text('SUBJECT',
                style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 1)),
          ),
          SizedBox(width: 8.w),
          Expanded(
            flex: 4,
            child: Text('ASSIGNED TA',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 1)),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 104.w,
            child: Text('PERMISSIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.sp,
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
          EdgeInsets.symmetric(horizontal: 9.w, vertical: 14.h),
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
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 6.h),
                Wrap(
                  spacing: 4.w,
                  runSpacing: 4.h,
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

          SizedBox(width: 8.w),

          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 5.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: hasTA
                      ? const Color(0xFF10B981)
                          .withValues(alpha: 0.13)
                      : Colors.grey.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasTA
                          ? Icons.person_rounded
                          : Icons.person_off_rounded,
                      size: 13.sp,
                      color: hasTA
                          ? const Color(0xFF10B981)
                          : Colors.grey,
                    ),
                    SizedBox(width: 5.w),
                    Flexible(
                      child: Text(
                        hasTA ? assignedTA.name : 'None',
                        style: TextStyle(
                          fontSize: 10.5.sp,
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

          SizedBox(width: 8.w),

          SizedBox(
            width: 104.w,
            child: ElevatedButton.icon(
              onPressed: () => _openSheet(subject, assignedTA, isDark),
              icon: Icon(Icons.tune_rounded, size: 13.sp),
              label: Text('Permissions',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                    horizontal: 6.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
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
  bool _dirty = false;
  StreamSubscription? _wsSub;
  Timer? _pollTimer;

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
    if (widget.assignedTA != null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted && !_isSaving && !_isLoading) {
          _load(silent: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _pollTimer?.cancel();
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
    if (silent && _dirty) return;
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final resp = await ApiService.getTASubjectPermissions(
        widget.assignedTA!.id,
        widget.subject.id,
        token,
      );
      if (mounted && !(silent && _dirty)) {
        setState(() {
          _canActivateSession = resp['can_activate_session'] ?? true;
          _canManageGrades = resp['can_manage_grades'] ?? true;
          _isLoading = false;
          _dirty = false;
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
        _dirty = false;
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
            BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(height: 18.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child: Icon(Icons.tune_rounded,
                      size: 22.sp, color: const Color(0xFF8B5CF6)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text('TA Permissions',
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: textPrimary)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(9.r),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 17.sp, color: textSub),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14.r),
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
                  SizedBox(height: 8.h),
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
          SizedBox(height: 12.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 13.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                    color: const Color(0xFFD97706)
                        .withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15.sp, color: const Color(0xFFD97706)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFFD97706)),
                        children: const [
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
          SizedBox(height: 16.h),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SkeletonCardList(
                itemCount: 3,
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 20),
              ),
            )
          else if (!hasTA)
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 20.w, vertical: 8.h),
              child: Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                      color:
                          Colors.orange.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'No TA assigned to this subject yet.',
                        style: TextStyle(
                            fontSize: 12.sp,
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
                  : () => setState(() {
                      _canActivateSession = !_canActivateSession;
                      _dirty = true;
                    }),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 20.w),
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
                  : () => setState(() {
                      _canManageGrades = !_canManageGrades;
                      _dirty = true;
                    }),
            ),
          ],

          SizedBox(height: 20.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isSaving || !hasTA) ? null : _save,
                    icon: _isSaving
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Icon(Icons.save_rounded,
                            size: 16.sp),
                    label: Text('Save',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                          vertical: 14.h),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
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
                      padding: EdgeInsets.symmetric(
                          vertical: 14.h),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14.r)),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 14.sp,
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
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9.5.sp,
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
        Icon(icon, size: 14.sp, color: iconColor),
        SizedBox(width: 8.w),
        Text('$label: ',
            style: TextStyle(fontSize: 13.sp, color: textSub)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13.sp,
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
            EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(9.r),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, size: 18.sp, color: iconColor),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  SizedBox(height: 2.h),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11.sp, color: textSub)),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                color: checked
                    ? const Color(0xFF8B5CF6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
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
                  ? Icon(Icons.check_rounded,
                      size: 14.sp, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
