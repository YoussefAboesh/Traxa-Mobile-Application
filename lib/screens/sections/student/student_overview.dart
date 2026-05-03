import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/lecture.dart';
import '../../../core/api_service.dart';
import '../../../core/helpers.dart'; 

class StudentOverview extends StatefulWidget {
  const StudentOverview({super.key});

  @override
  State<StudentOverview> createState() => _StudentOverviewState();
}

class _StudentOverviewState extends State<StudentOverview> {
  int? _currentSemester; // ✅ Fix: null لحد ما الـ API يرد

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

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final user = authState.user;

    // ✅ Fix: بيستخدم findStudentSafely بدل orElse: students.first
    final student = (user != null)
        ? findStudentSafely(
            userId: user.id,
            username: user.username,
            students: dataState.students,
          )
        : null;

    // لو الطالب مش موجود
    if (student == null) {
      return const Scaffold(
        body: Center(child: Text('Student data not found')),
      );
    }

    // ✅ Fix: المستوى من الطالب نفسه
    final currentLevel = student.level;

    // ✅ Fix: لو لسه مجاش الـ semester من API، استخدم 1 مؤقتاً
    final semester = _currentSemester ?? 1;

    final allSubjects = dataState.subjects;
    final allGrades = dataState.grades;

    final allVisibleGrades = allGrades
        .where((g) => g.studentId == student.id && g.isVisible)
        .toList();

    final currentSemesterGrades = allVisibleGrades
        .where((g) => g.level == currentLevel && g.semester == semester)
        .toList();

    final studentSubjects = dataState.getSubjectsForStudent(student);
    final studentLectures = dataState.getLecturesForStudent(student);

    // ✅ Fix: GPA من helpers.dart المشتركة
    final semesterGPA = calculateGPA(currentSemesterGrades, allSubjects);
    final cumulativeGPA = calculateGPA(allVisibleGrades, allSubjects);

    // ✅ Fix: getTodayDayName من helpers.dart
    final todayName = getTodayDayName();
    final todaysLectures = studentLectures.where((l) => l.day == todayName).toList();

    final recentGrades = List.of(currentSemesterGrades)
      ..sort((a, b) => b.total.compareTo(a.total));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.school, color: Theme.of(context).primaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          student.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15, fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Level $currentLevel • ${student.department}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            ),
          ),

          // Bento Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0,
              ),
              delegate: SliverChildListDelegate([
                _buildBentoCard('Total Subjects', '${studentSubjects.length}', Icons.book, [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]),
                _buildBentoCard('Total Lectures', '${studentLectures.length}', Icons.school, [const Color(0xFF0EA5E9), const Color(0xFF0284C7)]),
                _buildBentoCard('Semester GPA', semesterGPA.toStringAsFixed(2), Icons.trending_up, [const Color(0xFF10B981), const Color(0xFF059669)], subtitle: 'Semester $semester'),
                _buildBentoCard('Cumulative GPA', cumulativeGPA.toStringAsFixed(2), Icons.grade, [const Color(0xFFF59E0B), const Color(0xFFD97706)], subtitle: 'Overall'),
              ]),
            ),
          ),

          // Today's Schedule
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Theme.of(context).primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Text("Today's Schedule ($todayName)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Text('${todaysLectures.length}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (todaysLectures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No lectures today', style: TextStyle(color: Color(0xFF94A3B8)))),
                    )
                  else
                    ...todaysLectures.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: _buildLectureItem(l, context),
                    )),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Recent Grades
          if (recentGrades.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Recent Grades', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    ...recentGrades.take(5).map((g) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: _buildGradeItem(g),
                    )),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildBentoCard(String title, String value, IconData icon, List<Color> colors, {String? subtitle}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.6))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLectureItem(Lecture lecture, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 35, decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.access_time, size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text(lecture.timeDisplay, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  const SizedBox(width: 10),
                  const Icon(Icons.location_on, size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text(lecture.locationName, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeItem(dynamic grade) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(grade.subjectName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text('${grade.total.toInt()} / 100 - ${grade.gradeLetter}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ]),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [grade.gradeColor, grade.gradeColor.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text('${grade.total.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
        ],
      ),
    );
  }
}
