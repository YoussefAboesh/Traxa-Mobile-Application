// lib/screens/student_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:traxa_mobile/cubit/data/data_state.dart';
import '../cubit/auth/auth_cubit.dart';
import '../cubit/data/data_cubit.dart';
import '../cubit/theme/theme_cubit.dart';
import '../services/websocket_service.dart';
import '../widgets/settings_bottom_sheet.dart';
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
      icon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupWebSocketListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fullReload() async {
    if (_isReloading) return;
    setState(() => _isReloading = true);
    
    try {
      print('🔄 StudentScreen: Full reload started...');
      
      await context.read<AuthCubit>().refreshUserData();
      await context.read<DataCubit>().fullReload();
      
      final authState = context.read<AuthCubit>().state;
      if (authState.user != null && authState.token != null) {
        await context.read<DataCubit>().loadStudentGradesWithToken(
              authState.user!.id,
              authState.token!,
            );
      }
      
      print('✅ StudentScreen: Full reload completed');
      print('📅 Current Semester from DataCubit: ${context.read<DataCubit>().currentSemester}');
      print('📅 Current Academic Year from DataCubit: ${context.read<DataCubit>().currentAcademicYear}');
      
      if (mounted) {
        // ✅ إعادة بناء الـ UI بعد الـ reload
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text('Data refreshed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      print('📢 Semester changed to: S$semester');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Semester changed to S$semester - Updating...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _fullReload();
    });

    ws.academicYearStream.listen((year) async {
      if (!mounted) return;
      print('📢 Academic year changed to: $year');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Academic year changed to $year - Updating...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _fullReload();
    });

    ws.gradeUpdateStream.listen((gradeData) {
      if (!mounted) return;
      final authState = context.read<AuthCubit>().state;
      final studentId = gradeData['student_id'] as int?;

      if (authState.user != null && studentId == authState.user!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your grade has been updated!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        if (authState.token != null) {
          context.read<DataCubit>().loadStudentGradesWithToken(
                authState.user!.id,
                authState.token!,
              );
        }
      }
    });

    ws.registrationApprovedStream.listen((subjects) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration approved! (${subjects.length} subjects)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      context.read<DataCubit>().loadAllData();
    });

    ws.levelsPromotedStream.listen((data) async {
      if (!mounted) return;
      print('📢 Levels promoted - Auto reloading...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Levels promoted - Reloading data...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
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

        if (entity == 'grade' && (action == 'created' || action == 'updated')) {
          final gradeData = data['data'] as Map<String, dynamic>?;
          if (gradeData != null) {
            final studentId = gradeData['student_id'] as int?;
            final authState = context.read<AuthCubit>().state;
            if (authState.user != null && studentId == authState.user!.id) {
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
    final themeCubit = context.watch<ThemeCubit>();
    final student = authState.user;
    final isDarkMode = themeCubit.state.themeMode == ThemeMode.dark;
    
    // ✅ استخدام BlocBuilder بدلاً من watch للتأكد من إعادة البناء
    return BlocBuilder<DataCubit, DataState>(
      builder: (context, dataState) {
        final currentSemester = dataState.currentSemester;
        final currentAcademicYear = dataState.currentAcademicYear;

        if (student == null) {
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
                // ✅ أيقونة
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.school_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                // ✅ Semester Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timeline, size: 12, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 4),
                      Text(
                        'S$currentSemester',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // ✅ Academic Year Badge - يتم تحديثه تلقائياً لأن الـ BlocBuilder يعيد البناء
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 10, color: Colors.purple),
                      const SizedBox(width: 4),
                      Text(
                        currentAcademicYear,
                        style: const TextStyle(
                          fontSize: 10,
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
            leading: Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu_rounded, color: Theme.of(context).primaryColor),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded,
                    color: Theme.of(context).hintColor),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new notifications'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isReloading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF8B5CF6),
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          key: const ValueKey('refresh'),
                          color: Theme.of(context).primaryColor,
                          size: 22,
                        ),
                ),
                onPressed: _isReloading ? null : _fullReload,
              ),
              _buildAnimatedThemeToggle(isDarkMode),
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: StreamBuilder<bool>(
                  stream: Stream.periodic(const Duration(seconds: 1),
                      (_) => WebSocketService.instance.isConnected),
                  initialData: WebSocketService.instance.isConnected,
                  builder: (context, snapshot) {
                    final isConnected = snapshot.data ?? false;
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? Colors.green : Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: (isConnected ? Colors.green : Colors.red)
                                .withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          drawer: _buildDrawer(context, student),
          body: _sections[_selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
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
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                elevation: 0,
                items: _navItems,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedThemeToggle(bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        context.read<ThemeCubit>().toggleTheme();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return RotationTransition(
            turns: animation,
            child: ScaleTransition(
              scale: animation,
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<bool>(isDarkMode),
          margin: const EdgeInsets.only(right: 8),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [Colors.amber.shade300, Colors.orange.shade400]
                  : [Colors.indigo.shade400, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isDarkMode ? Colors.amber : Colors.purple)
                    .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: Colors.white,
            size: 18,
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

  Widget _buildDrawer(BuildContext context, dynamic student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      width: 280,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      student.name.isNotEmpty
                          ? student.name[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  student.username,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.badge,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Student',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    setSelectedIndex(3);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    _showSettingsDialog(context);
                  },
                ),
                const Divider(
                  color: Colors.white10,
                  thickness: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Traxa v2.0.0',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.redAccent
            : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDestructive
              ? Colors.redAccent
              : (isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
      ),
      trailing: isDestructive
          ? null
          : Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.grey.shade400,
            ),
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.05),
      splashColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SettingsBottomSheet(),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Text(
              'Logout',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthCubit>().logout();
              context.read<DataCubit>().clearData();
              WebSocketService.instance.disconnect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}