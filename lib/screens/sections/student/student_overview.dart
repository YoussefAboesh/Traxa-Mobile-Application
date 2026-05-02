// lib/screens/sections/student/student_overview.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../models/lecture.dart';
import '../../../core/api_service.dart';

class StudentOverview extends StatefulWidget {
  const StudentOverview({super.key});

  @override
  State<StudentOverview> createState() => _StudentOverviewState();
}

class _StudentOverviewState extends State<StudentOverview> {
  int _currentSemester = 2; // Default Semester 2
  int _currentLevel = 2;    // Default Level 2
  
  @override
  void initState() {
    super.initState();
    _loadCurrentAcademicState();
  }
  
  Future<void> _loadCurrentAcademicState() async {
    final sem = await ApiService.getCurrentSemester();
    if (mounted) {
      setState(() {
        _currentSemester = sem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;

    final user = authState.user;
    Student? student;

    if (user != null && dataState.students.isNotEmpty) {
      student = dataState.students.firstWhere(
        (s) => s.id == user.id || s.studentId == user.username,
        orElse: () => dataState.students.first,
      );
    }

    final studentRef = student; // استخدام مرجع ثابت للـ Null Safety

    // ✅ استخدام مستوى الطالب الحالي من قاعدة البيانات
    final currentStudentLevel = studentRef?.level ?? 2;
    
    // ✅ تحديث المستوى الحالي بناءً على الطالب
    if (_currentLevel != currentStudentLevel) {
      _currentLevel = currentStudentLevel;
    }

    final allSubjects = dataState.subjects;
    final allGrades = dataState.grades;
    
    // ✅ جميع درجات الطالب المرئية
    final allVisibleGrades = allGrades
        .where((g) => g.studentId == studentRef?.id && g.isVisible)
        .toList();
    
    // ✅ درجات المستوى الحالي - الترم الحالي فقط (لـ Semester GPA)
    final currentLevelCurrentSemesterGrades = allVisibleGrades
        .where((g) => g.level == _currentLevel && g.semester == _currentSemester)
        .toList();
    
    // ✅ المواد الدراسية للطالب (المقررة حسب مستواه)
    final studentSubjects = studentRef != null
        ? dataState.subjects.where((s) => 
            s.level == studentRef.level && 
            s.department == studentRef.department
          ).toList()
        : <Subject>[];
    
    // ✅ المحاضرات للطالب
    final studentLectures = studentRef != null
        ? dataState.lectures.where((l) => 
            l.level == studentRef.level && 
            l.department == studentRef.department
          ).toList()
        : <Lecture>[];
    
    // ✅ حساب Semester GPA (من درجات المستوى الحالي - الترم الحالي فقط)
    final semesterGPA = _calculateGPA(currentLevelCurrentSemesterGrades, allSubjects);
    
    // ✅ حساب Cumulative GPA (من كل الدرجات المرئية)
    final cumulativeGPA = _calculateGPA(allVisibleGrades, allSubjects);
    
    // ✅ درجات آخر ترم (للـ Recent Grades)
    final recentGrades = currentLevelCurrentSemesterGrades
      ..sort((a, b) => b.total.compareTo(a.total));

    final todayName = _getTodayDayName();
    final todaysLectures = studentLectures
        .where((l) => l.day == todayName)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header AppBar
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
                    child: Icon(
                      Icons.school,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          student?.name ?? 'Student',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Level ${student?.level ?? 1} • ${student?.department ?? 'General'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
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

          // Bento Grid - 4 cards (Total Subjects, Total Lectures, Semester GPA, Cumulative GPA)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final items = [
                    BentoItem(
                      title: 'Total Subjects',
                      value: studentSubjects.length.toString(),
                      icon: Icons.book,
                      gradientColors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                    ),
                    BentoItem(
                      title: 'Total Lectures',
                      value: studentLectures.length.toString(),
                      icon: Icons.school,
                      gradientColors: [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                    ),
                    BentoItem(
                      title: 'Semester GPA',
                      value: semesterGPA.toStringAsFixed(2),
                      subtitle: 'Semester $_currentSemester',
                      icon: Icons.trending_up,
                      gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
                    ),
                    BentoItem(
                      title: 'Cumulative GPA',
                      value: cumulativeGPA.toStringAsFixed(2),
                      subtitle: 'Overall',
                      icon: Icons.grade,
                      gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                    ),
                  ];
                  return _buildBentoCard(items[index]);
                },
                childCount: 4,
              ),
            ),
          ),

          // Today's Schedule
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).primaryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Today's Schedule",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  if (todaysLectures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'No lectures scheduled for today',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...todaysLectures.map((lecture) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: _buildLectureItem(lecture, context),
                    )),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Recent Grades (آخر ترم فقط)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.grade,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Recent Grades (Semester $_currentSemester)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  if (recentGrades.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'No grades published yet for this semester',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...recentGrades.take(5).map((grade) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: _buildGradeItem(grade),
                    )),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  // ✅ حساب GPA باستخدام Grade Points
  double _calculateGPA(List<Grade> grades, List<Subject> subjects) {
    if (grades.isEmpty) return 0.0;

    double totalPoints = 0;
    int totalCredits = 0;

    for (final grade in grades) {
      final subject = subjects.firstWhere(
        (s) => s.id == grade.subjectId,
        orElse: () => subjects.first,
      );
      final credits = subject.totalCreditHours;
      final gradePoint = grade.gradePoints;

      totalPoints += gradePoint * credits;
      totalCredits += credits;
    }

    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }

  Widget _buildBentoCard(BentoItem item) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: Colors.white,
                size: 18,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
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
          Container(
            width: 3,
            height: 35,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lecture.subjectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      lecture.timeDisplay,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on, size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      lecture.locationName,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Today',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeItem(Grade grade) {
    final percentage = grade.total;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.subjectName,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${grade.total.toInt()} / 100 - ${grade.gradeLetter}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  grade.gradeColor,
                  grade.gradeColor.withValues(alpha: 0.7)
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${percentage.toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTodayDayName() {
    const days = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
    ];
    return days[DateTime.now().weekday % 7];
  }
}

class BentoItem {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradientColors;

  BentoItem({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.gradientColors,
  });
}