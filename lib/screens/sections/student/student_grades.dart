// lib/screens/sections/student/student_grades.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';

class StudentGrades extends StatefulWidget {
  const StudentGrades({super.key});

  @override
  State<StudentGrades> createState() => _StudentGradesState();
}

class _StudentGradesState extends State<StudentGrades> {
  int _selectedSemester = 0; // 0 = All, 1 = Semester 1, 2 = Semester 2
  int _selectedLevel = 0; // 0 = All Levels

  final List<int> _levels = [1, 2, 3, 4];

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

    // فلترة درجات الطالب
    List<Grade> studentGrades =
        allGrades.where((g) => g.studentId == student?.id).toList();

    // فلترة حسب السيمستر
    if (_selectedSemester == 1) {
      studentGrades = studentGrades.where((g) => g.semester == 1).toList();
    } else if (_selectedSemester == 2) {
      studentGrades = studentGrades.where((g) => g.semester == 2).toList();
    }

    // فلترة حسب المستوى
    if (_selectedLevel != 0) {
      studentGrades = studentGrades
          .where((g) => g.level == _selectedLevel)
          .toList();
    }

    // ترتيب حسب المادة
    studentGrades.sort((a, b) => a.subjectName.compareTo(b.subjectName));

    // حساب الإحصائيات
    final totalCredits = _calculateTotalCredits(studentGrades, allSubjects);
    final subjectsPassed = studentGrades.where((g) => g.total >= 50).length;
    final subjectsFailed =
        studentGrades.where((g) => g.total < 50 && g.total > 0).length;

    // ✅ حساب Semester GPA و Cumulative GPA باستخدام المعادلة الجديدة
    final semester1Grades = studentGrades.where((g) => g.semester == 1).toList();
    final semester2Grades = studentGrades.where((g) => g.semester == 2).toList();
    
    final semester1GPA = _calculateGPA(semester1Grades, allSubjects);
    final semester2GPA = _calculateGPA(semester2Grades, allSubjects);
    final cumulativeGPA = _calculateGPA(studentGrades, allSubjects);

    // تحديد أي سيمستر نعرض
    final semesterToShow = _selectedSemester == 1 ? 1 : (_selectedSemester == 2 ? 2 : 1);
    final displaySemesterGPA = semesterToShow == 1 ? semester1GPA : semester2GPA;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
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
                      'title': 'GPA',
                      'value':
                          'S$semesterToShow: ${displaySemesterGPA.toStringAsFixed(2)}\nC: ${cumulativeGPA.toStringAsFixed(2)}',
                      'icon': Icons.trending_up,
                      'color': const Color(0xFF8B5CF6)
                    },
                    {
                      'title': 'Total Credits',
                      'value': totalCredits.toString(),
                      'icon': Icons.credit_card,
                      'color': const Color(0xFF10B981)
                    },
                    {
                      'title': 'Subjects Passed',
                      'value': subjectsPassed.toString(),
                      'icon': Icons.check_circle,
                      'color': const Color(0xFF34D399)
                    },
                    {
                      'title': 'Subjects Failed',
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  // Semester Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                        ),
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
                            fontSize: 13,
                          ),
                          icon: Icon(
                            Icons.filter_list,
                            color: Theme.of(context).primaryColor,
                            size: 18,
                          ),
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
                  const SizedBox(width: 12),
                  // Level Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                        ),
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
                            fontSize: 13,
                          ),
                          icon: Icon(
                            Icons.school,
                            color: Theme.of(context).primaryColor,
                            size: 18,
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: 0, child: Text('All Levels')),
                            ..._levels.map((level) => DropdownMenuItem(
                                  value: level,
                                  child: Text('Level $level'),
                                )),
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

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Grades Table
          if (studentGrades.isEmpty)
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
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : Colors.grey.shade600,
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
                  studentGrades
                      .map((grade) =>
                          _buildGradeCard(grade, allSubjects))
                      .toList(),
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
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05)
          ],
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
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
    final percentage = (grade.total / 100) * 100;
    final gradeLetter = _getGradeLetter(percentage);
    final gradeColor = _getGradeColor(percentage);
    final isPassed = grade.total >= 50;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gradeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Main Row
          InkWell(
            onTap: () {
              _showGradeDetailsDialog(grade, subject);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Code
                  Container(
                    width: 70,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      subject.code ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Subject Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade.subjectName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject.doctorName,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Level ${grade.level} • Semester ${grade.semester}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Grade and Button
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              gradeColor,
                              gradeColor.withValues(alpha: 0.7)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            grade.total.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              gradeLetter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: gradeColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: gradeColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Status Bar
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isPassed
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: gradeColor,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPassed ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGradeDetailsDialog(Grade grade, Subject subject) {
    final distribution = _getGradeDistribution(grade.doctorId, grade.subjectId);

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
            // Handle
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

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.code ?? 'N/A',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    grade.subjectName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject.doctorName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Level ${grade.level} • Semester ${grade.semester}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Grade Distribution Table
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
                        color: _getGradeColor((grade.total / 100) * 100)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grade Letter',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getGradeColor((grade.total / 100) * 100),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getGradeLetter((grade.total / 100) * 100),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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

  Widget _buildDistributionRow(String label, double earned, double max,
      {bool isTotal = false}) {
    final percentage = max > 0 ? (earned / max) * 100 : 0;
    final color =
        isTotal ? Theme.of(context).primaryColor : Colors.grey.shade600;

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
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ معادلة GPA محدثة حسب النظام العالمي 4.0
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
      final percentage = grade.total; // grade.total is out of 100

      // ✅ نظام 4.0 الدقيق (النطاقات الصحيحة)
      double gradePoint = 0;
      
      if (percentage >= 97) {
        gradePoint = 4.0; // A+
      } else if (percentage >= 93) {
        gradePoint = 4.0; // A
      } else if (percentage >= 90) {
        gradePoint = 3.7; // A-
      } else if (percentage >= 87) {
        gradePoint = 3.3; // B+
      } else if (percentage >= 83) {
        gradePoint = 3.0; // B
      } else if (percentage >= 80) {
        gradePoint = 2.7; // B-
      } else if (percentage >= 77) {
        gradePoint = 2.3; // C+
      } else if (percentage >= 73) {
        gradePoint = 2.0; // C
      } else if (percentage >= 70) {
        gradePoint = 1.7; // C-
      } else if (percentage >= 67) {
        gradePoint = 1.3; // D+
      } else if (percentage >= 63) {
        gradePoint = 1.0; // D
      } else if (percentage >= 60) {
        gradePoint = 0.7; // D-
      } else {
        gradePoint = 0.0; // F
      }

      totalPoints += gradePoint * credits;
      totalCredits += credits;
    }

    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }

  int _calculateTotalCredits(List<Grade> grades, List<Subject> subjects) {
    int total = 0;
    for (final grade in grades) {
      if (grade.total >= 50 && grade.isVisible) {
        final subject = subjects.firstWhere(
          (s) => s.id == grade.subjectId,
          orElse: () => subjects.first,
        );
        total += subject.totalCreditHours;
      }
    }
    return total;
  }

  String _getGradeLetter(double percentage) {
    if (percentage >= 97) return 'A+';
    if (percentage >= 93) return 'A';
    if (percentage >= 90) return 'A-';
    if (percentage >= 87) return 'B+';
    if (percentage >= 83) return 'B';
    if (percentage >= 80) return 'B-';
    if (percentage >= 77) return 'C+';
    if (percentage >= 73) return 'C';
    if (percentage >= 70) return 'C-';
    if (percentage >= 67) return 'D+';
    if (percentage >= 63) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 90) return const Color(0xFF10B981);
    if (percentage >= 80) return const Color(0xFF34D399);
    if (percentage >= 70) return const Color(0xFFFBBF24);
    if (percentage >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFF87171);
  }

  Map<String, double> _getGradeDistribution(int doctorId, int subjectId) {
    return {
      'midterm': 10,
      'oral': 5,
      'practical': 20,
      'attendance': 5,
      'assignment': 10,
      'final': 50,
    };
  }
}