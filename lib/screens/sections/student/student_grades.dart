// lib/screens/sections/student/student_grades.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/grade.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';
import '../../../core/api_service.dart';
import '../../../core/helpers.dart';
import '../../../widgets/app_skeleton.dart';

class StudentGrades extends StatefulWidget {
  const StudentGrades({super.key});

  @override
  State<StudentGrades> createState() => _StudentGradesState();
}

class _StudentGradesState extends State<StudentGrades> {
  int _selectedSemester = 0; // 0 = All Semesters, 1 = Semester 1, 2 = Semester 2
  int _selectedLevel = 0;
  final List<int> _levels = [1, 2, 3, 4];
  final Map<String, Map<String, double>> _distributionsCache = {};
  bool _isRefreshing = false;

  String getSemesterLabel() {
    if (_selectedSemester == 1) return 'S1';
    if (_selectedSemester == 2) return 'S2';
    return 'All';
  }

  Future<void> _refreshGrades() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final authState = context.read<AuthCubit>().state;
      final user = authState.user;

      if (user != null && authState.token != null) {
        await context.read<DataCubit>().loadStudentGradesWithToken(
              user.id,
              authState.token!,
            );
        // ignore: use_build_context_synchronously
        await context.read<DataCubit>().loadAllData();
      }
    } catch (e) {
      print('Error refreshing grades: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  double calculateCumulativeGPAForFilter(
      List<Grade> allVisibleGrades, List<Subject> allSubjects, int selectedLevel, int selectedSemester) {

    if (selectedLevel == 0) {
      return calculateGPA(allVisibleGrades, allSubjects);
    }

    List<Grade> cumulativeGrades = [];

    for (final grade in allVisibleGrades) {
      final subject = allSubjects.firstWhere(
        (s) => s.id == grade.subjectId,
        orElse: () => Subject(id: 0, name: '', doctorId: 0, doctorName: '', level: 1, semester: 1),
      );

      if (subject.level < selectedLevel) {
        cumulativeGrades.add(grade);
      }
      else if (subject.level == selectedLevel) {
        if (selectedSemester == 0) {
          cumulativeGrades.add(grade);
        } else if (selectedSemester == 1 && grade.semester == 1) {
          cumulativeGrades.add(grade);
        } else if (selectedSemester == 2 && grade.semester <= 2) {
          cumulativeGrades.add(grade);
        }
      }
    }

    return calculateGPA(cumulativeGrades, allSubjects);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;

    final realStudent = (user != null)
        ? findStudentSafely(
            userId: user.id,
            username: user.username,
            students: dataState.students)
        : null;

    if (realStudent == null && dataState.loadingState.isLoaded) {
      return const Scaffold(
          body: Center(child: Text('Student data not found')));
    }

    // أثناء التحميل بنعرض نفس شكل الصفحة كـ Skeleton.
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

    final allSubjects = dataState.allSubjects;
    final allGrades = dataState.allGrades;

    final allVisibleGrades = allGrades
        .where((g) => g.studentId == student.id && g.isVisible)
        .toList();

    List<Grade> filteredGrades = List.from(allVisibleGrades);
    if (_selectedSemester == 1) {
      filteredGrades = filteredGrades.where((g) => g.semester == 1).toList();
    } else if (_selectedSemester == 2) {
      filteredGrades = filteredGrades.where((g) => g.semester == 2).toList();
    }
    if (_selectedLevel != 0) {
      filteredGrades = filteredGrades.where((g) => g.level == _selectedLevel).toList();
    }
    filteredGrades.sort((a, b) => a.subjectName.compareTo(b.subjectName));

    final semesterGPA = calculateGPA(filteredGrades, allSubjects);
    final cumulativeGPA = calculateCumulativeGPAForFilter(
        allVisibleGrades, allSubjects, _selectedLevel, _selectedSemester);

    final totalCredits = calculateEarnedCredits(filteredGrades, allSubjects);
    final subjectsPassed = filteredGrades.where((g) => g.total >= 50).length;
    final subjectsFailed = filteredGrades.where((g) => g.total < 50 && g.total > 0).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSkeleton(
        enabled: showSkeleton,
        child: RefreshIndicator(
        onRefresh: _refreshGrades,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('My Grades'),
              centerTitle: false,
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),

            SliverPadding(
              padding: EdgeInsets.all(16.r),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1.6,
                ),
                delegate: SliverChildListDelegate([
                  _buildStatCard(
                    title: 'GPA',
                    value: '${getSemesterLabel()}: ${semesterGPA.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                    color: const Color(0xFF8B5CF6),
                  ),
                  _buildStatCard(
                    title: 'Cumulative',
                    value: cumulativeGPA.toStringAsFixed(2),
                    icon: Icons.grade,
                    color: const Color(0xFF0EA5E9),
                  ),
                  _buildStatCard(
                      title: 'Total Credits',
                      value: totalCredits.toString(),
                      icon: Icons.credit_card,
                      color: const Color(0xFF10B981)),
                  _buildStatCard(
                      title: 'Subjects',
                      value: 'P: $subjectsPassed / F: $subjectsFailed',
                      icon: Icons.book,
                      color: const Color(0xFFF59E0B)),
                ]),
              ),
            ),

            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedSemester,
                            isExpanded: true,
                            dropdownColor: Theme.of(context).cardColor,
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                fontSize: 13.sp),
                            icon: Icon(Icons.filter_list,
                                color: Theme.of(context).primaryColor,
                                size: 18.sp),
                            items: const [
                              DropdownMenuItem(
                                  value: 0, child: Text('All Semesters')),
                              DropdownMenuItem(
                                  value: 1, child: Text('Semester 1')),
                              DropdownMenuItem(
                                  value: 2, child: Text('Semester 2')),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedSemester = value ?? 0),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedLevel,
                            isExpanded: true,
                            dropdownColor: Theme.of(context).cardColor,
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                fontSize: 13.sp),
                            icon: Icon(Icons.layers,
                                color: Theme.of(context).primaryColor,
                                size: 18.sp),
                            items: [
                              const DropdownMenuItem(
                                  value: 0, child: Text('All Levels')),
                              ..._levels.map((l) => DropdownMenuItem(
                                  value: l, child: Text('Level $l'))),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedLevel = value ?? 0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(child: SizedBox(height: 16.h)),

            if (filteredGrades.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 64.sp, color: Colors.grey.shade400),
                      SizedBox(height: 16.h),
                      Text('No grades found',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey.shade500)),
                      SizedBox(height: 8.h),
                      Text('Try changing the filters',
                          style: TextStyle(
                              fontSize: 13.sp, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    child: _buildGradeCard(filteredGrades[index], allSubjects),
                  ),
                  childCount: filteredGrades.length,
                ),
              ),

            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20.sp, color: Colors.white70),
          SizedBox(height: 6.h),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          SizedBox(height: 2.h),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.sp, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildGradeCard(Grade grade, List<Subject> subjects) {
    final subject = findSubjectSafely(grade.subjectId, subjects);
    final isPassed = grade.isPassed;

    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: grade.gradeColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => _showGradeDetails(grade, subject, subjects),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        grade.gradeColor,
                        grade.gradeColor.withValues(alpha: 0.7)
                      ]),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: Text(grade.gradeLetter,
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(grade.subjectName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14.sp)),
                        SizedBox(height: 4.h),
                        // ✅ السيميستر تحت و wrap text
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 4.h,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                subject?.code ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                subject?.doctorName ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'Semester ${grade.semester}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${grade.total.toInt()}/100',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: grade.gradeColor)),
                      SizedBox(height: 4.h),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: isPassed
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(isPassed ? 'Pass' : 'Fail',
                            style: TextStyle(
                                fontSize: 10.sp,
                                color: isPassed ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGradeDetails(
      Grade grade, Subject? subject, List<Subject> subjects) async {
    final effectiveSubject = subject ??
        Subject(
            id: 0,
            name: grade.subjectName,
            doctorId: 0,
            doctorName: 'N/A',
            level: grade.level,
            semester: grade.semester);

    Map<String, double> distribution = {
      'midterm': 10,
      'oral': 5,
      'practical': 20,
      'attendance': 5,
      'assignment': 10,
      'final': 50,
    };

    final cacheKey = '${grade.doctorId}_${grade.subjectId}';
    if (_distributionsCache.containsKey(cacheKey)) {
      distribution = _distributionsCache[cacheKey]!;
    } else {
      final authState = context.read<AuthCubit>().state;
      if (authState.token != null) {
        final fetched = await ApiService.getGradeDistribution(
            grade.doctorId, grade.subjectId, authState.token!);
        if (fetched != null) {
          distribution = fetched;
          _distributionsCache[cacheKey] = fetched;
        }
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 48.w,
              height: 4.h,
              decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(4.r)),
            ),
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(effectiveSubject.code ?? 'N/A',
                      style: TextStyle(
                          fontSize: 14.sp, color: Theme.of(context).primaryColor)),
                  SizedBox(height: 4.h),
                  Text(grade.subjectName,
                      style: TextStyle(
                          fontSize: 22.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4.h),
                  Text(
                      'Semester ${grade.semester} - ${effectiveSubject.doctorName}',
                      style:
                          TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  children: [
                    _buildDistributionRow('Midterm Exam', grade.midterm,
                        distribution['midterm'] ?? 0),
                    _buildDistributionRow(
                        'Oral Exam', grade.oral, distribution['oral'] ?? 0),
                    _buildDistributionRow('Practical Exam', grade.practical,
                        distribution['practical'] ?? 0),
                    _buildDistributionRow('Attendance', grade.attendance,
                        distribution['attendance'] ?? 0),
                    _buildDistributionRow('Assignment', grade.assignment,
                        distribution['assignment'] ?? 0),
                    _buildDistributionRow('Final Exam', grade.finalExam,
                        distribution['final'] ?? 0),
                    const Divider(height: 32),
                    _buildDistributionRow('Total', grade.total, 100,
                        isTotal: true),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                          color: grade.gradeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grade Letter',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 8.h),
                            decoration: BoxDecoration(
                                color: grade.gradeColor,
                                borderRadius: BorderRadius.circular(20.r)),
                            child: Text(grade.gradeLetter,
                                style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionRow(String label, double earned, double max,
      {bool isTotal = false}) {
    final color =
        isTotal ? Theme.of(context).primaryColor : Colors.grey.shade600;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: isTotal ? 16.sp : 14.sp,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                      color: color)),
              Text('${earned.toInt()} / ${max.toInt()}',
                  style: TextStyle(
                      fontSize: isTotal ? 16.sp : 14.sp,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                      color: color)),
            ],
          ),
          SizedBox(height: 4.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: max > 0 ? earned / max : 0,
              backgroundColor: Colors.grey.shade200,
              color: isTotal ? Theme.of(context).primaryColor : Colors.blue,
              minHeight: 6.h,
            ),
          ),
        ],
      ),
    );
  }
}
