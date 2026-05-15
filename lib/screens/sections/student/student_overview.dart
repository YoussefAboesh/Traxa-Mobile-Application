// lib/screens/sections/student/student_overview.dart
// ignore_for_file: use_build_context_synchronously, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:traxa_mobile/models/lecture.dart';
import 'package:traxa_mobile/models/subject.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/api_service.dart';
import '../../../core/helpers.dart';
import '../../../core/theme.dart';
import '../../../models/grade.dart';

class StudentOverview extends StatefulWidget {
  const StudentOverview({super.key});

  @override
  State<StudentOverview> createState() => _StudentOverviewState();
}

class _StudentOverviewState extends State<StudentOverview> {
  int? _currentSemester;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSemester();
  }

  Future<void> _loadCurrentSemester() async {
    final sem = await ApiService.getCurrentSemester();
    if (mounted) {
      setState(() => _currentSemester = sem);
    }
  }

  /// حساب GPA التراكمي من أول مستوى 1 لحد مستوى وسيمستر معين
  double _calculateCumulativeGPAUpTo(List<Grade> allVisibleGrades, List<Subject> allSubjects, int upToLevel, int upToSemester) {
    List<Grade> cumulativeGrades = [];
    
    for (final grade in allVisibleGrades) {
      final subject = allSubjects.firstWhere(
        (s) => s.id == grade.subjectId,
        orElse: () => Subject(id: 0, name: '', doctorId: 0, doctorName: '', level: 1, semester: 1),
      );
      
      if (subject.level < upToLevel) {
        cumulativeGrades.add(grade);
      } 
      else if (subject.level == upToLevel) {
        if (upToSemester == 2 && grade.semester <= 2) {
          cumulativeGrades.add(grade);
        } else if (upToSemester == 1 && grade.semester == 1) {
          cumulativeGrades.add(grade);
        }
      }
    }
    
    return calculateGPA(cumulativeGrades, allSubjects);
  }

  String _getTrendStatus(double currentGpa, double previousGpa) {
    if (previousGpa == 0.0 || currentGpa == 0.0) {
      return 'nodata';
    }
    if (currentGpa > previousGpa) {
      return 'above';
    } else if (currentGpa < previousGpa) {
      return 'below';
    } else {
      return 'stable';
    }
  }

  String _getTrendText(String status) {
    switch (status) {
      case 'above':
        return 'Above';
      case 'below':
        return 'Below';
      case 'stable':
        return 'Stable';
      default:
        return 'No data';
    }
  }

  IconData _getTrendIcon(String status) {
    switch (status) {
      case 'above':
        return Icons.arrow_upward_rounded;
      case 'below':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  Color _getTrendColor(String status) {
    switch (status) {
      case 'above':
        return const Color(0xFF10B981);
      case 'below':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<DataCubit>().loadAllData();
      final authState = context.read<AuthCubit>().state;
      if (authState.user != null && authState.token != null) {
        await context.read<DataCubit>().loadStudentGradesWithToken(
          authState.user!.id,
          authState.token!,
        );
      }
      await _loadCurrentSemester();
    } catch (e) {
      print('Error refreshing: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String getGradeLabel(double gpa) {
    if (gpa >= 3.7) return 'Excellent';
    if (gpa >= 3.3) return 'Very Good';
    if (gpa >= 2.7) return 'Good';
    if (gpa >= 2.0) return 'Satisfactory';
    if (gpa >= 1.7) return 'Pass';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = context.isDarkMode;
    final user = authState.user;

    final student = (user != null)
        ? findStudentSafely(
            userId: user.id,
            username: user.username,
            students: dataState.students,
          )
        : null;

    if (student == null) {
      return const Scaffold(
        body: Center(child: Text('Student data not found')),
      );
    }

    final currentLevel = student.level;
    final semester = _currentSemester ?? dataState.currentSemester;
    final semesterDisplay = semester == 1 ? 'First Semester' : 'Second Semester';
    final academicYear = dataState.currentAcademicYear;

    final allSubjects = dataState.allSubjects;
    final allGrades = dataState.allGrades;
    final allVisibleGrades = allGrades
        .where((g) => g.studentId == student.id && g.isVisible)
        .toList();

    final currentSemesterGrades = allVisibleGrades
        .where((g) => g.level == currentLevel && g.semester == semester)
        .toList();

    final studentSubjects = dataState.getSubjectsForStudent(student);
    final studentLectures = dataState.getLecturesForStudent(student);
    final studentSections = dataState.getSectionsForStudent(student);

    final todayName = getTodayDayName();
    final todaysLectures =
        studentLectures.where((l) => l.day == todayName).toList();
    final todaysSections =
        studentSections.where((s) => s.day == todayName).toList();
    
    // Combine lectures and sections for today
    final todaySchedule = <dynamic>[...todaysLectures, ...todaysSections];
    todaySchedule.sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));

    final now = DateTime.now();
    final dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final formattedDate =
        '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}, ${now.year}';

    // ================= GPA CURRENT =================

    final semesterGPA = calculateGPA(currentSemesterGrades, allSubjects);

    int latestLevelWithGrades = 1;
    int latestSemesterWithGrades = 1;
    for (final grade in allVisibleGrades) {
      if (
          grade.level > latestLevelWithGrades ||
          (grade.level == latestLevelWithGrades &&
              grade.semester > latestSemesterWithGrades)) {
        latestLevelWithGrades = grade.level;
        latestSemesterWithGrades = grade.semester;
      }
    }

    final currentCumulativeGPA = _calculateCumulativeGPAUpTo(
      allVisibleGrades,
      allSubjects,
      latestLevelWithGrades,
      latestSemesterWithGrades,
    );

    // ================= PREVIOUS GPA =================

    int previousLevelForSemester = currentLevel;
    int previousSemesterNumForSemester = 1;

    if (semester == 1) {
      previousSemesterNumForSemester = 2;
      previousLevelForSemester = currentLevel - 1;
      if (previousLevelForSemester <= 0) {
        previousLevelForSemester = 1;
        previousSemesterNumForSemester = 1;
      }
    } else {
      previousSemesterNumForSemester = 1;
    }

    final previousSemesterGrades = allVisibleGrades.where((g) {
      final subject = allSubjects.where((s) => s.id == g.subjectId).firstOrNull;
      if (subject == null) return false;
      return subject.level == previousLevelForSemester &&
          g.semester == previousSemesterNumForSemester;
    }).toList();

    final previousSemesterGPA = calculateGPA(previousSemesterGrades, allSubjects);
    final semesterTrendStatus = _getTrendStatus(semesterGPA, previousSemesterGPA);
    final semesterLabel = getGradeLabel(semesterGPA);

    // ================= CUMULATIVE PREVIOUS =================

    int previousLevelForCumulative;
    int previousSemesterForCumulative;

    if (latestSemesterWithGrades == 2) {
      previousLevelForCumulative = latestLevelWithGrades;
      previousSemesterForCumulative = 1;
    } else {
      previousLevelForCumulative = latestLevelWithGrades - 1;
      previousSemesterForCumulative = 2;
      if (previousLevelForCumulative <= 0) {
        previousLevelForCumulative = 1;
        previousSemesterForCumulative = 1;
      }
    }

    final previousCumulativeGPA = _calculateCumulativeGPAUpTo(
      allVisibleGrades,
      allSubjects,
      previousLevelForCumulative,
      previousSemesterForCumulative,
    );

    final cumulativeTrendStatus = _getTrendStatus(currentCumulativeGPA, previousCumulativeGPA);
    final cumulativeLabel = getGradeLabel(currentCumulativeGPA);

    final semesterCredits =
        studentSubjects.fold<int>(0, (sum, s) => sum + (s.totalCreditHours));
    final totalCredits = allVisibleGrades.fold<int>(0, (sum, g) {
      final subject = allSubjects.where((s) => s.id == g.subjectId).firstOrNull;
      return sum + (subject?.totalCreditHours ?? 0);
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            // Hero Header
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                        : [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back, ${student.name.split(' ').first} 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Track your academic performance at a glance',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 7, color: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text('Active',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.layers_rounded,
                                      size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Semester $semester',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // GPA Cards Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGpaCard(
                        context,
                        gpa: semesterGPA,
                        label: semesterLabel,
                        credits: semesterCredits,
                        subjects: studentSubjects.length,
                        trendStatus: semesterTrendStatus,
                        color: const Color(0xFF8B5CF6),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGpaCard(
                        context,
                        gpa: currentCumulativeGPA,
                        label: cumulativeLabel,
                        credits: totalCredits,
                        subjects: allVisibleGrades.map((g) => g.subjectId).toSet().length,
                        trendStatus: cumulativeTrendStatus,
                        color: const Color(0xFF0EA5E9),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Today's Schedule
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today_rounded,
                                color: Color(0xFF8B5CF6), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today\'s Schedule',
                                  style: TextStyle(
                                    color: Color(0xFF8B5CF6),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              todayName,
                              style: const TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    if (todaySchedule.isEmpty)
                      _buildEmptySchedule(isDark)
                    else
                      ...todaySchedule.map((item) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: _buildScheduleItem(
                              context,
                              name: item.subjectName,
                              time: item.timeDisplay,
                              location: item.locationName,
                              teacher: item is Lecture ? item.doctorName : item.taName,
                              type: item is Lecture ? 'Lec' : 'Sec',
                              typeColor: item is Lecture 
                                  ? const Color(0xFF8B5CF6) 
                                  : const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          )),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            const SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // GPA Card Widget
  Widget _buildGpaCard(
    BuildContext context, {
    required double gpa,
    required String label,
    required int credits,
    required int subjects,
    required String trendStatus,
    required Color color,
    required bool isDark,
  }) {
    final trendIcon = _getTrendIcon(trendStatus);
    final trendText = _getTrendText(trendStatus);
    final trendColor = _getTrendColor(trendStatus);
    final showTrend = trendStatus != 'nodata';
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white54 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            gpa.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'GPA',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (showTrend)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(trendIcon, size: 14, color: trendColor),
                const SizedBox(width: 4),
                Text(
                  trendText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 20),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$credits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Credits',
                    style: TextStyle(
                      fontSize: 10,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '$subjects',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Subjects',
                    style: TextStyle(
                      fontSize: 10,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySchedule(bool isDark) {
    final textColor = isDark ? const Color(0xFF64748B) : Colors.grey.shade500;
    final iconColor = isDark ? const Color(0xFF334155) : Colors.grey.shade400;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_rounded,
                size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              'No lectures or sections scheduled for today',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text('Enjoy your day off! 🎉',
                style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(
    BuildContext context, {
    required String name,
    required String time,
    required String location,
    required String teacher,
    required String type,
    required Color typeColor,
    required bool isDark,
  }) {
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.shade100;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(time,
                        style: TextStyle(
                            fontSize: 10, color: subTextColor)),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on_rounded,
                        size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(location,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: subTextColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.school_rounded,
                        size: 10, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        teacher,
                        style: TextStyle(
                            fontSize: 10, color: subTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}