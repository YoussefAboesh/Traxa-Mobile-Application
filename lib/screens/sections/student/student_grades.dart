// lib/screens/sections/student/student_grades.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../core/api_service.dart';

class StudentGrades extends StatefulWidget {
  const StudentGrades({super.key});

  @override
  State<StudentGrades> createState() => _StudentGradesState();
}

class _StudentGradesState extends State<StudentGrades> {
  int _selectedSemester = 0; // 0 = All, 1 = Semester 1, 2 = Semester 2
  int _selectedLevel = 0; // 0 = All Levels
  final List<int> _levels = [1, 2, 3, 4];
  
  // تخزين توزيعات الدرجات مؤقتاً
  final Map<String, Map<String, double>> _distributionsCache = {};

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;
    Student? student;

    if (user != null && dataState.students.isNotEmpty) {
      student = dataState.students.firstWhere(
        (s) => s.id == user.id || s.studentId == user.username,
        orElse: () => dataState.students.first,
      );
    }

    final allSubjects = dataState.subjects;
    final allGrades = dataState.grades;

    // 1. الحصول على جميع درجات الطالب (بدون فلترة)
    final studentAllGrades = allGrades.where((g) => g.studentId == student?.id).toList();

    // 2. حساب المعدل التراكمي (Cumulative GPA) دائماً من كل الدرجات
    final cumulativeGPA = _calculateGPA(studentAllGrades, allSubjects);

    // 3. فلترة الدرجات للعرض حسب الاختيارات (Level & Semester)
    List<Grade> displayGrades = List.from(studentAllGrades);

    if (_selectedSemester != 0) {
      displayGrades = displayGrades.where((g) => g.semester == _selectedSemester).toList();
    }

    if (_selectedLevel != 0) {
      displayGrades = displayGrades.where((g) => g.level == _selectedLevel).toList();
    }

    // ترتيب حسب المادة
    displayGrades.sort((a, b) => a.subjectName.compareTo(b.subjectName));

    // 4. حساب إحصائيات القائمة المفلترة
    final filteredGPA = _calculateGPA(displayGrades, allSubjects);
    final totalCredits = _calculateTotalCredits(displayGrades, allSubjects);
    final subjectsPassed = displayGrades.where((g) => g.isPassed && g.isVisible).length;
    final subjectsFailed = displayGrades.where((g) => !g.isPassed && g.total > 0 && g.isVisible).length;

    // تحديد عنوان GPA للعرض
    final gpaLabel = _selectedSemester == 0 ? 'GPA' : 'Sem $_selectedSemester GPA';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('My Grades'),
            centerTitle: false,
            floating: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),

          // Stats Cards
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final stats = [
                    {
                      'title': gpaLabel,
                      'value': 'Term: ${filteredGPA.toStringAsFixed(2)}\nCum: ${cumulativeGPA.toStringAsFixed(2)}',
                      'icon': Icons.trending_up,
                      'color': const Color(0xFF8B5CF6)
                    },
                    {
                      'title': 'Credits (Selected)',
                      'value': totalCredits.toString(),
                      'icon': Icons.credit_card,
                      'color': const Color(0xFF10B981)
                    },
                    {
                      'title': 'Passed',
                      'value': subjectsPassed.toString(),
                      'icon': Icons.check_circle,
                      'color': const Color(0xFF34D399)
                    },
                    {
                      'title': 'Failed',
                      'value': subjectsFailed.toString(),
                      'icon': Icons.cancel,
                      'color': const Color(0xFFF87171)
                    },
                  ];
                  if (index < 4) {
                    final stat = stats[index];
                    return _buildStatCard(
                      title: stat['title'] as String,
                      value: stat['value'] as String,
                      icon: stat['icon'] as IconData,
                      color: stat['color'] as Color,
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount: 4,
              ),
            ),
          ),

          // Filters Row
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedSemester,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 13,
                          ),
                          icon: Icon(Icons.filter_list, color: Theme.of(context).primaryColor, size: 18),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('All Semesters')),
                            DropdownMenuItem(value: 1, child: Text('Semester 1')),
                            DropdownMenuItem(value: 2, child: Text('Semester 2')),
                          ],
                          onChanged: (value) => setState(() => _selectedSemester = value ?? 0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedLevel,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 13,
                          ),
                          icon: Icon(Icons.school, color: Theme.of(context).primaryColor, size: 18),
                          items: [
                            const DropdownMenuItem(value: 0, child: Text('All Levels')),
                            ..._levels.map((level) => DropdownMenuItem(
                              value: level,
                              child: Text('Level $level'),
                            )),
                          ],
                          onChanged: (value) => setState(() => _selectedLevel = value ?? 0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Grades Table
          if (displayGrades.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'No grades available for the selected filters',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  displayGrades.map((grade) => _buildGradeCard(grade, allSubjects)).toList(),
                ),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: title == 'GPA' ? 16 : 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeCard(Grade grade, List<Subject> subjects) {
    final subject = subjects.firstWhere(
      (s) => s.id == grade.subjectId,
      orElse: () => subjects.first,
    );
    final percentage = grade.total;
    final gradeLetter = grade.letterGrade;
    final gradeColor = grade.gradeColor;
    final isPassed = grade.isPassed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showGradeDetailsDialog(grade, subject),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      subject.code ?? 'N/A',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: gradeColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade.subjectName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject.doctorName,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Level ${grade.level} • Semester ${grade.semester}',
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [gradeColor, gradeColor.withValues(alpha: 0.7)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            grade.total.toInt().toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              gradeLetter,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: gradeColor),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 16, color: gradeColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isPassed ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
            ),
            child: FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isPassed ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${percentage.toInt()}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gradeColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPassed ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPassed ? 'PASS' : 'FAIL',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPassed ? Colors.green : Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ جلب توزيعة الدرجات من الـ API
  Future<Map<String, double>> _fetchGradeDistribution(int doctorId, int subjectId, String token) async {
    final cacheKey = '${doctorId}_$subjectId';
    
    if (_distributionsCache.containsKey(cacheKey)) {
      return _distributionsCache[cacheKey]!;
    }
    
    try {
      final response = await ApiService.getGradeDistribution(doctorId, subjectId, token);
      if (response != null && response.isNotEmpty) {
        _distributionsCache[cacheKey] = response;
        return response;
      }
    } catch (e) {
      print('Error fetching grade distribution: $e');
    }
    
    final defaultDist = {
      'midterm': 10.0,
      'oral': 5.0,
      'practical': 20.0,
      'attendance': 5.0,
      'assignment': 10.0,
      'final': 50.0,
    };
    _distributionsCache[cacheKey] = defaultDist;
    return defaultDist;
  }

  void _showGradeDetailsDialog(Grade grade, Subject subject) async {
    final authState = context.read<AuthCubit>().state;
    final token = authState.token;
    
    if (token == null) return;
    
    final distribution = await _fetchGradeDistribution(grade.doctorId, grade.subjectId, token);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.code ?? 'N/A',
                    style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    grade.subjectName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject.doctorName,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Level ${grade.level} • Semester ${grade.semester}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDistributionRow(
                      'Midterm Exam',
                      grade.midterm,
                      distribution['midterm'] ?? 0,
                    ),
                    _buildDistributionRow(
                      'Oral Exam',
                      grade.oral,
                      distribution['oral'] ?? 0,
                    ),
                    _buildDistributionRow(
                      'Practical Exam',
                      grade.practical,
                      distribution['practical'] ?? 0,
                    ),
                    _buildDistributionRow(
                      'Attendance',
                      grade.attendance,
                      distribution['attendance'] ?? 0,
                    ),
                    _buildDistributionRow(
                      'Assignment',
                      grade.assignment,
                      distribution['assignment'] ?? 0,
                    ),
                    _buildDistributionRow(
                      'Final Exam',
                      grade.finalExam,
                      distribution['final'] ?? 0,
                    ),
                    const Divider(height: 32),
                    _buildDistributionRow(
                      'Total',
                      grade.total,
                      100,
                      isTotal: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: grade.gradeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grade Letter', style: TextStyle(fontWeight: FontWeight.w500)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: grade.gradeColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              grade.letterGrade,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
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

  Widget _buildDistributionRow(String label, double earned, double max, {bool isTotal = false}) {
    final percentage = max > 0 ? (earned / max) * 100 : 0;
    final color = isTotal ? Theme.of(context).primaryColor : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isTotal ? 16 : 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
              Text(
                '${earned.toInt()} / ${max.toInt()}',
                style: TextStyle(
                  fontSize: isTotal ? 16 : 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: max > 0 ? earned / max : 0,
              backgroundColor: Colors.grey.shade200,
              color: isTotal ? Theme.of(context).primaryColor : Colors.blue,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toInt()}%',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ✅ حساب GPA حسب النظام الجديد
  double _calculateGPA(List<Grade> grades, List<Subject> subjects) {
    if (grades.isEmpty) return 0.0;

    double totalPoints = 0;
    int totalCredits = 0;

    for (final grade in grades) {
      if (!grade.isVisible) continue;

      final subject = subjects.firstWhere(
        (s) => s.id == grade.subjectId,
        orElse: () => subjects.first,
      );
      final credits = subject.totalCreditHours;

      // استخدام خصائص النموذج مباشرة لتبسيط الحساب
      double gradePoint = grade.gradePoints;

      totalPoints += gradePoint * credits;
      totalCredits += credits;
    }

    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }

  int _calculateTotalCredits(List<Grade> grades, List<Subject> subjects) {
    int total = 0;
    for (final grade in grades) {
      if (grade.isPassed && grade.isVisible) {
        final subject = subjects.firstWhere(
          (s) => s.id == grade.subjectId,
          orElse: () => subjects.first,
        );
        total += subject.totalCreditHours;
      }
    }
    return total;
  }
}