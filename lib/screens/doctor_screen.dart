// lib/screens/doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/auth/auth_cubit.dart';
import '../cubit/data/data_cubit.dart';
import '../cubit/data/data_state.dart';
import '../cubit/theme/theme_cubit.dart';
import '../services/websocket_service.dart';
import '../widgets/settings_bottom_sheet.dart';
import 'sections/doctor/doctor_overview.dart';
import 'sections/doctor/doctor_subjects.dart';
import 'sections/doctor/doctor_attendance.dart';
import 'sections/doctor/doctor_reports.dart';

class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  int _selectedIndex = 0;
  bool _isReloading = false;

  final List<Widget> _sections = [
    const DoctorOverview(),
    const DoctorSubjects(),
    const DoctorAttendance(),
    const DoctorReports(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_rounded),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.book_rounded),
      label: 'Subjects',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.how_to_reg_rounded),
      label: 'Attendance',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.analytics_rounded),
      label: 'Reports',
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
      print('🔄 DoctorScreen: Full reload started...');
      
      await context.read<AuthCubit>().refreshUserData();
      // ignore: use_build_context_synchronously
      await context.read<DataCubit>().fullReload();
      
      print('✅ DoctorScreen: Full reload completed');
      // ignore: use_build_context_synchronously
      print('📅 Current Semester: ${context.read<DataCubit>().currentSemester}');
      // ignore: use_build_context_synchronously
      print('📅 Current Academic Year: ${context.read<DataCubit>().currentAcademicYear}');
      
      if (mounted) {
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

    ws.sessionActivatedStream.listen((data) {
      if (!mounted) return;
      final session = data['session'] as Map<String, dynamic>?;
      final subjectName = session?['subjectName'] ?? 'Unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session activated: $subjectName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      if (_selectedIndex == 2) {
        context.read<DataCubit>().loadAllData();
      }
    });

    ws.sessionEndedStream.listen((data) {
      if (!mounted) return;
      final sessionId = data['sessionId'] as String? ?? 'Unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session ended: $sessionId'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
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
    final themeCubit = context.watch<ThemeCubit>();
    final doctor = authState.user;
    final isDarkMode = themeCubit.state.themeMode == ThemeMode.dark;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? doctorEmail;
    if (doctor != null) {
      final dataState = context.read<DataCubit>().state;
      if (dataState.doctors.isNotEmpty) {
        final doctorData = dataState.doctors.firstWhere(
          (d) => d.id == doctor.id || d.username == doctor.username,
          orElse: () => dataState.doctors.first,
        );
        doctorEmail = doctorData.email;
      }
    }

    if (doctor == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    return BlocBuilder<DataCubit, DataState>(
      builder: (context, dataState) {
        final currentSemester = dataState.currentSemester;
        final currentAcademicYear = dataState.currentAcademicYear;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ أيقونة الدكتور
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.medical_services_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                // ✅ Semester Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timeline, size: 12, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 4),
                      Text(
                        'S$currentSemester',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // ✅ Academic Year Badge
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
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
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
                            color: Color(0xFF0EA5E9),
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
          drawer: _buildDrawer(context, doctor, doctorEmail),
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
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                selectedItemColor: const Color(0xFF0EA5E9),
                unselectedItemColor:
                    isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
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
    const doctorPrimaryColor = Color(0xFF0EA5E9);

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
                  : [
                      doctorPrimaryColor,
                      doctorPrimaryColor.withValues(alpha: 0.7)
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isDarkMode ? Colors.amber : doctorPrimaryColor)
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

  Widget _buildDrawer(BuildContext context, dynamic doctor, String? email) {
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
                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
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
                      doctor.name.isNotEmpty
                          ? doctor.name[0].toUpperCase()
                          : 'D',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  doctor.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.username,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                        Icons.school_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Professor',
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
      splashColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
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