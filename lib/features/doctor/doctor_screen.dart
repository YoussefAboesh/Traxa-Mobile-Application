// ignore_for_file: duplicate_ignore, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../cubit/auth/auth_cubit.dart';
import '../../cubit/auth/auth_state.dart';
import '../../cubit/data/data_cubit.dart';
import '../../cubit/data/data_state.dart';
import '../../models/user.dart';
import '../../services/websocket_service.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/academic_year_chip.dart';
import '../../widgets/ws_connection_dot.dart';
import '../../widgets/app_snack.dart';
import '../../core/logger.dart';
import 'sections/doctor_overview.dart';
import 'sections/doctor_subjects.dart';
import 'sections/doctor_attendance.dart';
import 'sections/doctor_reports.dart';
import 'sections/doctor_profile.dart';

/// Doctor / TA shell. Uses ValueNotifier for local UI state and IndexedStack
/// for tabs so sections keep their state across tab switches.
class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  final _selectedIndex = ValueNotifier<int>(0);
  final _isReloading = ValueNotifier<bool>(false);
  final _academicYear = ValueNotifier<String>('2026-2027');
  final _semester = ValueNotifier<int>(1);

  String _pendingAcademicYear = '';
  bool _sessionExpiredHandled = false;

  final List<StreamSubscription<dynamic>> _wsSubs = [];

  static const _allTabs = [
    {'label': 'Home', 'icon': Icons.dashboard_rounded},
    {'label': 'Subjects', 'icon': Icons.book_rounded},
    {'label': 'Attendance', 'icon': Icons.how_to_reg_rounded},
    {'label': 'Reports', 'icon': Icons.analytics_rounded},
    {'label': 'Profile', 'icon': Icons.person_rounded},
  ];

  static const List<Widget> _sections = [
    DoctorOverview(),
    DoctorSubjects(),
    DoctorAttendance(),
    DoctorReports(),
    DoctorProfile(),
  ];

  @override
  void initState() {
    super.initState();
    _setupWebSocketListeners();
    _loadFreshDataOnStart();
  }

  @override
  void dispose() {
    for (final s in _wsSubs) {
      s.cancel();
    }
    _selectedIndex.dispose();
    _isReloading.dispose();
    _academicYear.dispose();
    _semester.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data
  Future<void> _loadFreshDataOnStart() async {
    try {
      logDebug('🔄 Loading fresh data on app start...');
      await context.read<DataCubit>().fullReload();
      if (!mounted) return;
      final s = context.read<DataCubit>().state;
      _academicYear.value = s.currentAcademicYear;
      _semester.value = s.currentSemester;
    } catch (e) {
      logDebug('❌ Error loading fresh data: $e');
    }
  }

  Future<void> _fullReload() async {
    if (_isReloading.value) return;
    _isReloading.value = true;
    try {
      logDebug('🔄 DoctorScreen: Full reload started...');
      final savedYear = _academicYear.value;

      await context.read<AuthCubit>().refreshUserData();
      await context.read<DataCubit>().fullReload();

      if (!mounted) return;
      final dataState = context.read<DataCubit>().state;
      _academicYear.value =
          _pendingAcademicYear.isNotEmpty ? _pendingAcademicYear : savedYear;
      _semester.value = dataState.currentSemester;

      _showSnack(
        'Data refreshed successfully!',
        Colors.green,
        Icons.check_circle,
      );
    } catch (e) {
      logDebug('❌ Full reload error: $e');
      if (mounted) {
        _showSnack('Error: $e', Colors.red, Icons.error_outline);
      }
    } finally {
      if (mounted) _isReloading.value = false;
    }
  }

  void _handleSessionExpired() {
    if (!mounted || _sessionExpiredHandled) return;
    _sessionExpiredHandled = true;
    _showSnack('Session expired. Please login again.', Colors.orange, Icons.lock_clock);
    context.read<DataCubit>().clearData();
    context.read<AuthCubit>().logout();
  }

  void _showSnack(String message, Color color, IconData icon) {
    AppSnack.custom(context, message, color: color, icon: icon);
  }

  // ---------------------------------------------------------------- websocket
  void _setupWebSocketListeners() {
    final ws = WebSocketService.instance;

    _wsSubs.add(ws.semesterStream.listen((semester) async {
      if (!mounted) return;
      logDebug('📢 WebSocket - Semester changed to: S$semester');
      _semester.value = semester;
      await _fullReload();
    }));

    _wsSubs.add(ws.academicYearStream.listen((year) async {
      if (!mounted) return;
      logDebug('📢 WebSocket - Academic year changed to: $year');
      _pendingAcademicYear = year;
      _academicYear.value = year;
      await _fullReload();
      _pendingAcademicYear = '';
    }));

    _wsSubs.add(ws.sessionActivatedStream.listen((_) {
      if (!mounted) return;
      if (_selectedIndex.value == 2) {
        context.read<DataCubit>().loadAllData();
      }
    }));

    _wsSubs.add(ws.sessionEndedStream.listen((_) {
      if (!mounted) return;
      if (_selectedIndex.value == 2) {
        context.read<DataCubit>().loadAllData();
      }
    }));

    _wsSubs.add(ws.gradeUpdateStream.listen((gradeData) {
      if (!mounted) return;
      final studentId = gradeData['student_id'] as int?;
      final total = (gradeData['total'] as num?)?.toDouble();
      _showSnack(
        'Grade updated for student #$studentId: $total%',
        Colors.green,
        Icons.update,
      );
      if (_selectedIndex.value == 3) {
        context.read<DataCubit>().loadAllData();
      }
    }));

    _wsSubs.add(ws.levelsPromotedStream.listen((_) async {
      if (!mounted) return;
      logDebug('📢 Levels promoted - Auto reloading...');
      _showSnack('Levels promoted - Reloading data...', Colors.blue, Icons.arrow_upward);
      await _fullReload();
    }));

    _wsSubs.add(ws.taPermissionsStream.listen((data) {
      if (!mounted) return;
      final user = context.read<AuthCubit>().state.user;
      if (user == null || !user.isTeachingAssistant) return;
      if (data['taId'] != user.id) return;
      final perms = data['permissions'];
      if (perms is Map) {
        context
            .read<AuthCubit>()
            .updateUserPermissions(Map<String, dynamic>.from(perms));
        _showSnack(
          'Your permissions were updated',
          const Color(0xFF8B5CF6),
          Icons.shield,
        );
      }
    }));

    _wsSubs.add(ws.dataChangeStream.listen((data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      if (type == 'TOKEN_EXPIRED') {
        _handleSessionExpired();
        return;
      }
      if (type == 'DATA_CHANGE') {
        final entity = data['entity'] as String?;
        logDebug('📱 DoctorScreen: Data change - $entity / ${data['action']}');
        if (entity == 'subject' || entity == 'lecture') {
          if (_selectedIndex.value == 0 || _selectedIndex.value == 1) {
            context.read<DataCubit>().loadAllData();
          }
        }
      } else if (type == 'FULL_SYNC') {
        logDebug('📱 Full sync received - Auto reloading...');
        _fullReload();
      }
    }));
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return BlocSelector<AuthCubit, AuthState, User?>(
      selector: (s) => s.user,
      builder: (context, doctor) {
        if (doctor == null) {
          return const Scaffold(body: Center(child: Text('User not found')));
        }

        return Scaffold(
          appBar: _DoctorAppBar(
            academicYear: _academicYear,
            isReloading: _isReloading,
            onReload: _fullReload,
          ),
          body: _DoctorBody(
            selectedIndex: _selectedIndex,
            onSessionExpired: _handleSessionExpired,
            onRetry: _fullReload,
            isReloading: _isReloading,
          ),
          bottomNavigationBar: _DoctorBottomNav(selectedIndex: _selectedIndex),
        );
      },
    );
  }
}

class _DoctorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DoctorAppBar({
    required this.academicYear,
    required this.isReloading,
    required this.onReload,
  });

  final ValueNotifier<String> academicYear;
  final ValueNotifier<bool> isReloading;
  final VoidCallback onReload;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.asset(
                'icons/doctor_logo.png',
                width: 38.w,
                height: 38.w,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 8.w),
            AcademicYearChip(year: academicYear),
          ],
        ),
      ),
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: isReloading,
          builder: (context, loading, _) => IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: Theme.of(context)
                  .primaryColor
                  .withValues(alpha: loading ? 0.4 : 1.0),
              size: 22.sp,
            ),
            onPressed: loading ? null : onReload,
          ),
        ),
        const ThemeToggleButton(),
        const WsConnectionDot(),
      ],
    );
  }
}

/// IndexedStack keeps all sections alive across tab switches so their state
/// (scroll position, form input, etc.) is preserved.
class _DoctorBody extends StatelessWidget {
  const _DoctorBody({
    required this.selectedIndex,
    required this.onSessionExpired,
    required this.onRetry,
    required this.isReloading,
  });

  final ValueNotifier<int> selectedIndex;
  final VoidCallback onSessionExpired;
  final VoidCallback onRetry;
  final ValueNotifier<bool> isReloading;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DataCubit, DataState>(
      buildWhen: (prev, curr) =>
          prev.loadingState != curr.loadingState ||
          prev.students.length != curr.students.length ||
          prev.subjects.length != curr.subjects.length,
      builder: (context, dataState) {
        // Session-expired check.
        if (dataState.loadingState.hasError &&
            (dataState.loadingState.errorMessage ?? '')
                .contains('Session expired')) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => onSessionExpired());
        }

        if (dataState.loadingState.hasError &&
            dataState.students.isEmpty &&
            dataState.subjects.isEmpty) {
          return ValueListenableBuilder<bool>(
            valueListenable: isReloading,
            builder: (context, loading, _) => CustomErrorWidget(
              message: dataState.loadingState.errorMessage ?? 'Failed to load data',
              onRetry: loading ? null : onRetry,
            ),
          );
        }

        return ValueListenableBuilder<int>(
          valueListenable: selectedIndex,
          builder: (context, idx, _) => IndexedStack(
            index: idx.clamp(0, _DoctorScreenState._sections.length - 1),
            children: _DoctorScreenState._sections,
          ),
        );
      },
    );
  }
}

class _DoctorBottomNav extends StatelessWidget {
  const _DoctorBottomNav({required this.selectedIndex});
  final ValueNotifier<int> selectedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20.r,
            offset: Offset(0, -5.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: selectedIndex,
          builder: (context, idx, _) => BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: idx.clamp(0, _DoctorScreenState._allTabs.length - 1),
            onTap: (i) => selectedIndex.value = i,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            selectedItemColor: const Color(0xFF0EA5E9),
            unselectedItemColor:
                isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            selectedLabelStyle:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp),
            unselectedLabelStyle:
                TextStyle(fontWeight: FontWeight.w500, fontSize: 12.sp),
            elevation: 0,
            items: _DoctorScreenState._allTabs
                .map((t) => BottomNavigationBarItem(
                      icon: Icon(t['icon'] as IconData),
                      label: t['label'] as String,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
