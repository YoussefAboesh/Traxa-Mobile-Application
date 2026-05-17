// lib/screens/sections/student/student_overview.dart
// ignore_for_file: use_build_context_synchronously, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:traxa_mobile/models/lecture.dart';
import 'package:traxa_mobile/models/student.dart';
import 'package:traxa_mobile/models/subject.dart';
import 'package:traxa_mobile/models/section.dart';
import 'package:traxa_mobile/models/teaching_assistant.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/api_service.dart';
import '../../../core/helpers.dart';
import '../../../core/theme.dart';
import '../../../models/grade.dart';
import '../../../widgets/app_skeleton.dart';

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

  /// يحلّ اسم المعيد للسكشن فوراً من البيانات المحمّلة (من غير أي API call).
  String _sectionTAName(
    Section section,
    List<TeachingAssistant> tas,
    List<Subject> subjects,
  ) {
    final fromSection = section.taName.trim();
    if (fromSection.isNotEmpty && fromSection.toLowerCase() != 'ta') {
      return fromSection;
    }
    if (section.taId != null) {
      final m = tas.where((t) => t.id == section.taId).toList();
      if (m.isNotEmpty && m.first.name.trim().isNotEmpty) {
        return m.first.name;
      }
    }
    final subj = subjects.where((s) => s.id == section.subjectId).toList();
    if (subj.isNotEmpty) {
      final tn = subj.first.taName?.trim();
      if (tn != null && tn.isNotEmpty && tn.toLowerCase() != 'not assigned') {
        return tn;
      }
    }
    return 'TA';
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

  /// صفوف وهمية تُعرض كـ Skeleton أثناء تحميل بيانات الطالب.
  List<Lecture> _placeholderLectures() {
    return List.generate(
      2,
      (i) => Lecture(
        id: -1 - i,
        subjectId: 0,
        subjectName: 'Subject Name',
        doctorId: 0,
        doctorName: 'Doctor Name',
        level: 1,
        department: 'General',
        day: '',
        timeslotId: 0,
        timeDisplay: '00:00 - 00:00',
        locationId: 0,
        locationName: 'Location',
        active: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = context.isDarkMode;
    final user = authState.user;

    final realStudent = (user != null)
        ? findStudentSafely(
            userId: user.id,
            username: user.username,
            students: dataState.students,
          )
        : null;

    // الطالب مش موجود والبيانات اتحمّلت فعلاً → رسالة فقط.
    if (realStudent == null && dataState.loadingState.isLoaded) {
      return const Scaffold(
        body: Center(child: Text('Student data not found')),
      );
    }

    // أثناء التحميل بنعرض نفس شكل الصفحة بالظبط كـ Skeleton (مش شكل عام).
    final bool showSkeleton =
        dataState.loadingState.isLoading || realStudent == null;
    final student = realStudent ??
        Student(
          id: 0,
          name: 'Student Name',
          studentId: '00000000',
          level: 1,
          department: 'General',
        );

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
    // أثناء التحميل بنحط صفوف وهمية عشان الـ Skeleton يبان زي شكل الصفحة.
    if (showSkeleton && todaySchedule.isEmpty) {
      todaySchedule.addAll(_placeholderLectures());
    }

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
      body: AppSkeleton(
        enabled: showSkeleton,
        child: RefreshIndicator(
        onRefresh: _refreshData,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            // Hero Header
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                        : [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Track your academic performance at a glance',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 5.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 7.sp, color: const Color(0xFF10B981)),
                                  SizedBox(width: 4.w),
                                  Text('Active',
                                      style: TextStyle(
                                          fontSize: 11.sp,
                                          color: const Color(0xFF10B981),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 5.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.layers_rounded,
                                      size: 12.sp, color: Colors.white),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Semester $semester',
                                    style: TextStyle(
                                        fontSize: 11.sp,
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

            SliverToBoxAdapter(child: SizedBox(height: 16.h)),

            // GPA Cards Row
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                    SizedBox(width: 12.w),
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

            SliverToBoxAdapter(child: SizedBox(height: 16.h)),

            // Today's Schedule
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20.r),
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
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(Icons.calendar_today_rounded,
                                color: const Color(0xFF8B5CF6), size: 18.sp),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today\'s Schedule',
                                  style: TextStyle(
                                    color: const Color(0xFF8B5CF6),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              todayName,
                              style: TextStyle(
                                  color: const Color(0xFF8B5CF6),
                                  fontSize: 11.sp,
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
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
                            child: _buildScheduleItem(
                              context,
                              name: item.subjectName,
                              time: item.timeDisplay,
                              location: item.locationName,
                              teacher: item is Lecture
                                  ? item.doctorName
                                  : _sectionTAName(
                                      item as Section,
                                      dataState.teachingAssistants,
                                      dataState.allSubjects),
                              type: item is Lecture ? 'Lec' : 'Sec',
                              typeColor: item is Lecture
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          )),
                    SizedBox(height: 12.h),
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
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            gpa.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'GPA',
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          if (showTrend)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(trendIcon, size: 14.sp, color: trendColor),
                SizedBox(width: 4.w),
                Text(
                  trendText,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ],
            )
          else
            SizedBox(height: 20.h),
          SizedBox(height: 12.h),
          const Divider(height: 1),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$credits',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Credits',
                    style: TextStyle(
                      fontSize: 10.sp,
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
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Subjects',
                    style: TextStyle(
                      fontSize: 10.sp,
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
      padding: EdgeInsets.symmetric(vertical: 36.h),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_rounded,
                size: 48.sp, color: iconColor),
            SizedBox(height: 12.h),
            Text(
              'No lectures or sections scheduled for today',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 13.sp),
            ),
            SizedBox(height: 4.h),
            Text('Enjoy your day off! 🎉',
                style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11.sp)),
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
      padding: EdgeInsets.all(12.r),
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 10.sp, color: const Color(0xFF94A3B8)),
                    SizedBox(width: 3.w),
                    Text(time,
                        style: TextStyle(
                            fontSize: 10.sp, color: subTextColor)),
                    SizedBox(width: 10.w),
                    Icon(Icons.location_on_rounded,
                        size: 10.sp, color: const Color(0xFF94A3B8)),
                    SizedBox(width: 3.w),
                    Flexible(
                      child: Text(location,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.sp, color: subTextColor)),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.school_rounded,
                        size: 10.sp, color: const Color(0xFF64748B)),
                    SizedBox(width: 3.w),
                    Flexible(
                      child: Text(
                        teacher,
                        style: TextStyle(
                            fontSize: 10.sp, color: subTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 9.sp,
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
