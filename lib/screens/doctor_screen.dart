// lib/screens/doctor_screen.dart
// ignore_for_file: duplicate_ignore, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../cubit/auth/auth_cubit.dart';
import '../cubit/data/data_cubit.dart';
import '../services/websocket_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'sections/doctor/doctor_overview.dart';
import 'sections/doctor/doctor_subjects.dart';
import 'sections/doctor/doctor_attendance.dart';
import 'sections/doctor/doctor_reports.dart';
import 'sections/doctor/doctor_profile.dart';

class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  int _selectedIndex = 0;
  bool _isReloading = false;

  String _localAcademicYear = '2026-2027';
  int _localSemester = 1;
  String _pendingAcademicYear = '';

  static const _allTabs = [
    {'key': 'ta.nav.overview', 'label': 'Home', 'icon': Icons.dashboard_rounded},
    {'key': 'ta.nav.subjects', 'label': 'Subjects', 'icon': Icons.book_rounded},
    {'key': 'ta.nav.attendance', 'label': 'Attendance', 'icon': Icons.how_to_reg_rounded},
    {'key': 'ta.nav.reports', 'label': 'Reports', 'icon': Icons.analytics_rounded},
    {'key': 'ta.nav.profile', 'label': 'Profile', 'icon': Icons.person_rounded},
  ];

  static const List<Widget> _allSections = [
    DoctorOverview(),
    DoctorSubjects(),
    DoctorAttendance(),
    DoctorReports(),
    DoctorProfile(),
  ];

  List<Map<String, Object>> _visibleTabs(dynamic user) {
    return _allTabs.map((t) => Map<String, Object>.from(t)).toList();
  }

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
      print('🔄 DoctorScreen: Full reload started...');
      final savedYear = _localAcademicYear;

      await context.read<AuthCubit>().refreshUserData();
      await context.read<DataCubit>().fullReload();

      final dataState = context.read<DataCubit>().state;
      setState(() {
        if (_pendingAcademicYear.isNotEmpty) {
          _localAcademicYear = _pendingAcademicYear;
        } else {
          _localAcademicYear = savedYear;
        }
        _localSemester = dataState.currentSemester;
      });

      print('✅ DoctorScreen: Full reload completed, Year: $_localAcademicYear, Semester: $_localSemester');

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
      setState(() => _localSemester = semester);
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
      setState(() => _pendingAcademicYear = '');
    });

    // Session activated/ended: the Attendance screen handles its own syncing
    // and user-facing messages, so no global snackbar here (it used to show
    // a confusing "Session activated: Unknown").
    ws.sessionActivatedStream.listen((data) {
      if (!mounted) return;
      if (_selectedIndex == 2) {
        context.read<DataCubit>().loadAllData();
      }
    });

    ws.sessionEndedStream.listen((data) {
      if (!mounted) return;
      if (_selectedIndex == 2) {
        context.read<DataCubit>().loadAllData();
      }
    });

    ws.gradeUpdateStream.listen((gradeData) {
      if (!mounted) return;
      final studentId = gradeData['student_id'] as int?;
      final total = (gradeData['total'] as num?)?.toDouble();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Grade updated for student #$studentId: $total%'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );

      if (_selectedIndex == 3) {
        context.read<DataCubit>().loadAllData();
      }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      await _fullReload();
    });

    ws.taPermissionsStream.listen((data) {
      if (!mounted) return;
      final user = context.read<AuthCubit>().state.user;
      if (user == null || !user.isTeachingAssistant) return;
      final taId = data['taId'];
      if (taId != user.id) return;
      final perms = data['permissions'];
      if (perms is Map) {
        context
            .read<AuthCubit>()
            .updateUserPermissions(Map<String, dynamic>.from(perms));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.shield, color: Colors.white, size: 18.sp),
                SizedBox(width: 12.w),
                const Text('Your permissions were updated'),
              ],
            ),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
        );
      }
    });

    ws.dataChangeStream.listen((data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      if (type == 'DATA_CHANGE') {
        final entity = data['entity'] as String?;
        final action = data['action'] as String?;
        print('📱 DoctorScreen: Data change - $entity / $action');

        if (entity == 'subject' || entity == 'lecture') {
          if (_selectedIndex == 0 || _selectedIndex == 1) {
            context.read<DataCubit>().loadAllData();
          }
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
    final doctor = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (doctor == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
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
          const ThemeToggleButton(),
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
      body: () {
        final tabs = _visibleTabs(doctor);
        if (tabs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.r),
              child: const Text(
                'No sections enabled. Ask your doctor to grant permissions.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final idx = _selectedIndex.clamp(0, tabs.length - 1);
        final key = tabs[idx]['key'];
        final orig = _allTabs.indexWhere((t) => t['key'] == key);
        return _allSections[orig >= 0 ? orig : 0];
      }(),
      bottomNavigationBar: _visibleTabs(doctor).length < 2
          ? null
          : Container(
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
            currentIndex: _selectedIndex.clamp(0, _visibleTabs(doctor).length - 1),
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            selectedItemColor: const Color(0xFF0EA5E9),
            unselectedItemColor: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12.sp,
            ),
            elevation: 0,
            items: _visibleTabs(doctor)
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

  void setSelectedIndex(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }
}
