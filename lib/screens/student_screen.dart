// lib/screens/student_screen.dart
// ignore_for_file: invalid_null_aware_operator, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../cubit/auth/auth_cubit.dart';
import '../cubit/data/data_cubit.dart';
import '../services/websocket_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'sections/student/student_overview.dart';
import 'sections/student/student_schedule.dart';
import 'sections/student/student_grades.dart';
import 'sections/student/student_profile.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  int _selectedIndex = 0;
  bool _isReloading = false;

  // Local variables for immediate UI update
  String _localAcademicYear = '2026-2027';
  int _localSemester = 1;

  // Store the new year from WebSocket
  String _pendingAcademicYear = '';

  final List<Widget> _sections = [
    const StudentOverview(),
    const StudentSchedule(),
    const StudentGrades(),
    const StudentProfile(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_rounded),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.schedule_rounded),
      label: 'Schedule',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.grade_rounded),
      label: 'Grades',
    ),
    const BottomNavigationBarItem(
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
    super.dispose();
  }

  Future<void> _loadFreshDataOnStart() async {
    try {
      print('🔄 Loading fresh data on app start...');
      await context.read<DataCubit>().fullReload();

      final authState = context.read<AuthCubit>().state;
      if (authState.user != null && authState.token != null) {
        await context.read<DataCubit>().loadStudentGradesWithToken(
              authState.user!.id,
              authState.token!,
            );
      }

      final updatedState = context.read<DataCubit>().state;
      if (mounted) {
        setState(() {
          _localAcademicYear = updatedState.currentAcademicYear;
          _localSemester = updatedState.currentSemester;
        });
      }
      print('📅 Loaded: Year=$_localAcademicYear, Semester=$_localSemester');
    } catch (e) {
      print('❌ Error loading fresh data: $e');
    }
  }

  Future<void> _fullReload() async {
    if (_isReloading) return;
    setState(() => _isReloading = true);

    try {
      print('🔄 StudentScreen: Full reload started...');

      final savedYear = _localAcademicYear;

      await context.read<AuthCubit>().refreshUserData();
      await context.read<DataCubit>().fullReload();

      final authState = context.read<AuthCubit>().state;
      if (authState.user != null && authState.token != null) {
        await context.read<DataCubit>().loadStudentGradesWithToken(
              authState.user!.id,
              authState.token!,
            );
      }

      final dataState = context.read<DataCubit>().state;
      setState(() {
        if (_pendingAcademicYear.isNotEmpty) {
          _localAcademicYear = _pendingAcademicYear;
        } else {
          _localAcademicYear = savedYear;
        }
        _localSemester = dataState.currentSemester;
      });

      print(
          '✅ StudentScreen: Full reload completed, Year: $_localAcademicYear, Semester: $_localSemester');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18.sp),
                SizedBox(width: 12.w),
                const Text('Data refreshed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    } catch (e) {
      print('❌ Full reload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18.sp),
                SizedBox(width: 12.w),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
      }
    }
  }

  void _setupWebSocketListeners() {
    final ws = WebSocketService.instance;

    ws.semesterStream.listen((semester) async {
      if (!mounted) return;
      print('📢 WebSocket - Semester changed to: S$semester');

      setState(() {
        _localSemester = semester;
      });

      await _fullReload();
    });

    ws.academicYearStream.listen((year) async {
      if (!mounted) return;
      print('📢 WebSocket - Academic year changed to: $year');

      setState(() {
        _pendingAcademicYear = year;
        _localAcademicYear = year;
      });

      await _fullReload();

      setState(() {
        _pendingAcademicYear = '';
      });
    });

    ws.gradeUpdateStream.listen((gradeData) {
      if (!mounted) return;
      final authState = context.read<AuthCubit>().state;
      if (authState.user == null || authState.token == null) return;

      final rawId = gradeData['student_id'] ?? gradeData['studentId'];
      final studentId = int.tryParse(rawId?.toString() ?? '');

      if (studentId == null || studentId == authState.user!.id) {
        final isVisible = gradeData['isVisible'] ?? gradeData['is_visible'];
        if (isVisible != false && studentId == authState.user!.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Your grade has been updated!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
            ),
          );
        }
        context.read<DataCubit>().loadStudentGradesWithToken(
              authState.user!.id,
              authState.token!,
            );
      }
    });

    ws.registrationApprovedStream.listen((subjects) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration approved! (${subjects.length} subjects)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      context.read<DataCubit>().loadAllData();
    });

    ws.levelsPromotedStream.listen((data) async {
      if (!mounted) return;
      print('📢 Levels promoted - Auto reloading...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Levels promoted - Reloading data...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      await _fullReload();
    });

    ws.dataChangeStream.listen((data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      if (type == 'DATA_CHANGE') {
        final entity = data['entity'] as String?;
        final action = data['action'] as String?;
        print('📱 StudentScreen: Data change - $entity / $action');

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
        print('📱 Full sync received - Auto reloading...');
        _fullReload();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: FaIcon(FontAwesomeIcons.userGraduate, color: Colors.white, size: 18.sp),
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 10.sp, color: Colors.purple),
                  SizedBox(width: 4.w),
                  Text(
                    _localAcademicYear,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            // الريفريش بقى بيظهر Skeleton جوّه الصفحة بدل الدايرة التقليدية،
            // فالزرار بيفضل أيقونة بس بتبهت شوية أثناء التحميل.
            icon: Icon(
              Icons.refresh_rounded,
              color: Theme.of(context).primaryColor.withValues(
                    alpha: _isReloading ? 0.4 : 1.0,
                  ),
              size: 22.sp,
            ),
            onPressed: _isReloading ? null : _fullReload,
          ),
          const ThemeToggleButton(lightModeColor: Color(0xFF8B5CF6)),
          Container(
            margin: EdgeInsets.only(right: 8.w),
            child: StreamBuilder<bool>(
              stream: Stream.periodic(const Duration(seconds: 1),
                  (_) => WebSocketService.instance.isConnected),
              initialData: WebSocketService.instance.isConnected,
              builder: (context, snapshot) {
                final isConnected = snapshot.data ?? false;
                return Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.green : Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? Colors.green : Colors.red)
                            .withValues(alpha: 0.5),
                        blurRadius: 4.r,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: _sections[_selectedIndex],
      bottomNavigationBar: Container(
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
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor:
                Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            selectedItemColor: const Color(0xFF8B5CF6),
            unselectedItemColor: Theme.of(context).hintColor,
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12.sp,
            ),
            elevation: 0,
            items: _navItems,
          ),
        ),
      ),
    );
  }

  void setSelectedIndex(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }
}
