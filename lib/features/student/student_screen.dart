// ignore_for_file: invalid_null_aware_operator, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import 'sections/student_overview.dart';
import 'sections/student_schedule.dart';
import 'sections/student_grades.dart';
import 'sections/student_profile.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final _selectedIndex = ValueNotifier<int>(0);
  final _isReloading = ValueNotifier<bool>(false);
  final _academicYear = ValueNotifier<String>('2026-2027');
  final _semester = ValueNotifier<int>(1);

  String _pendingAcademicYear = '';
  bool _sessionExpiredHandled = false;

  final List<StreamSubscription<dynamic>> _wsSubs = [];

  static const List<Widget> _sections = [
    StudentOverview(),
    StudentSchedule(),
    StudentGrades(),
    StudentProfile(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.schedule_rounded), label: 'Schedule'),
    BottomNavigationBarItem(icon: Icon(Icons.grade_rounded), label: 'Grades'),
    BottomNavigationBarItem(
      icon: FaIcon(FontAwesomeIcons.userGraduate),
      label: 'Profile',
    ),
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

      final authState = context.read<AuthCubit>().state;
      if (authState.user != null && authState.token != null) {
        await context.read<DataCubit>().loadStudentGradesWithToken(
              authState.user!.id,
              authState.token!,
            );
      }
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
      logDebug('🔄 StudentScreen: Full reload started...');
      final savedYear = _academicYear.value;

      await context.read<AuthCubit>().refreshUserData();
      await context.read<DataCubit>().fullReload();

      if (!mounted) return;
      final authState = context.read<AuthCubit>().state;
      if (authState.user != null && authState.token != null) {
        await context.read<DataCubit>().loadStudentGradesWithToken(
              authState.user!.id,
              authState.token!,
            );
      }

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

    _wsSubs.add(ws.gradeUpdateStream.listen((gradeData) {
      if (!mounted) return;
      final authState = context.read<AuthCubit>().state;
      if (authState.user == null || authState.token == null) return;

      final rawId = gradeData['student_id'] ?? gradeData['studentId'];
      final studentId = int.tryParse(rawId?.toString() ?? '');

      if (studentId == null || studentId == authState.user!.id) {
        final isVisible = gradeData['isVisible'] ?? gradeData['is_visible'];
        if (isVisible != false && studentId == authState.user!.id) {
          _showSnack('Your grade has been updated!', Colors.green, Icons.grade);
        }
        context.read<DataCubit>().loadStudentGradesWithToken(
              authState.user!.id,
              authState.token!,
            );
      }
    }));

    _wsSubs.add(ws.registrationApprovedStream.listen((subjects) {
      if (!mounted) return;
      _showSnack(
        'Registration approved! (${subjects.length} subjects)',
        Colors.green,
        Icons.check_circle,
      );
      context.read<DataCubit>().loadAllData();
    }));

    _wsSubs.add(ws.levelsPromotedStream.listen((_) async {
      if (!mounted) return;
      logDebug('📢 Levels promoted - Auto reloading...');
      _showSnack('Levels promoted - Reloading data...', Colors.blue, Icons.arrow_upward);
      await _fullReload();
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
        logDebug('📱 StudentScreen: Data change - $entity / ${data['action']}');

        if (entity == 'grade') {
          final authState = context.read<AuthCubit>().state;
          if (authState.user != null && authState.token != null) {
            final gradeData = data['data'] as Map<String, dynamic>?;
            final rawId = gradeData?['student_id'] ?? gradeData?['studentId'];
            final studentId = int.tryParse(rawId?.toString() ?? '');
            if (studentId == null || studentId == authState.user!.id) {
              context.read<DataCubit>().loadStudentGradesWithToken(
                    authState.user!.id,
                    authState.token!,
                  );
            }
          }
        } else if (entity == 'student' ||
            entity == 'subject' ||
            entity == 'lecture') {
          context.read<DataCubit>().loadAllData();
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
      builder: (context, user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('User not found')));
        }

        return Scaffold(
          appBar: _StudentAppBar(
            academicYear: _academicYear,
            isReloading: _isReloading,
            onReload: _fullReload,
          ),
          body: _StudentBody(
            selectedIndex: _selectedIndex,
            isReloading: _isReloading,
            onSessionExpired: _handleSessionExpired,
            onRetry: _fullReload,
          ),
          bottomNavigationBar: _StudentBottomNav(selectedIndex: _selectedIndex),
        );
      },
    );
  }
}

class _StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StudentAppBar({
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
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Image.asset(
              'icons/student_logo.jpg',
              width: 38.w,
              height: 38.w,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 8.w),
          AcademicYearChip(year: academicYear),
        ],
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
        const ThemeToggleButton(lightModeColor: Color(0xFF8B5CF6)),
        const WsConnectionDot(),
      ],
    );
  }
}

/// IndexedStack keeps each section alive across tab switches so its state
/// (scroll, form input) survives.
class _StudentBody extends StatelessWidget {
  const _StudentBody({
    required this.selectedIndex,
    required this.isReloading,
    required this.onSessionExpired,
    required this.onRetry,
  });

  final ValueNotifier<int> selectedIndex;
  final ValueNotifier<bool> isReloading;
  final VoidCallback onSessionExpired;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DataCubit, DataState>(
      buildWhen: (prev, curr) =>
          prev.loadingState != curr.loadingState ||
          prev.students.length != curr.students.length ||
          prev.subjects.length != curr.subjects.length,
      builder: (context, dataState) {
        if (dataState.loadingState.hasError &&
            (dataState.loadingState.errorMessage ?? '')
                .contains('Session expired')) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => onSessionExpired());
        }

        final hasFatalError = dataState.loadingState.hasError &&
            dataState.students.isEmpty &&
            dataState.subjects.isEmpty;

        if (hasFatalError) {
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
            index: idx.clamp(0, _StudentScreenState._sections.length - 1),
            children: _StudentScreenState._sections,
          ),
        );
      },
    );
  }
}

class _StudentBottomNav extends StatelessWidget {
  const _StudentBottomNav({required this.selectedIndex});
  final ValueNotifier<int> selectedIndex;

  @override
  Widget build(BuildContext context) {
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
            currentIndex: idx,
            onTap: (i) => selectedIndex.value = i,
            backgroundColor:
                Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            selectedItemColor: const Color(0xFF8B5CF6),
            unselectedItemColor: Theme.of(context).hintColor,
            selectedLabelStyle:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 12.sp),
            unselectedLabelStyle:
                TextStyle(fontWeight: FontWeight.w500, fontSize: 12.sp),
            elevation: 0,
            items: _StudentScreenState._navItems,
          ),
        ),
      ),
    );
  }
}
