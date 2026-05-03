// lib/screens/sections/student/student_grades.dart
// ✅ Fixes: orElse → findStudentSafely / findSubjectSafely + GPA من helpers
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/grade.dart';
import '../../../models/subject.dart';
import '../../../core/api_service.dart';
import '../../../core/helpers.dart';

class StudentGrades extends StatefulWidget {
  const StudentGrades({super.key});

  @override
  State<StudentGrades> createState() => _StudentGradesState();
}

class _StudentGradesState extends State<StudentGrades> {
  int _selectedSemester = 0;
  int _selectedLevel = 0;
  final List<int> _levels = [1, 2, 3, 4];
  final Map<String, Map<String, double>> _distributionsCache = {};

  String getSemesterLabel() {
    if (_selectedSemester == 1) return 'S1';
    if (_selectedSemester == 2) return 'S2';
    return 'AS';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;

    // ✅ Fix: بدل orElse: () => dataState.students.first
    final student = (user != null)
        ? findStudentSafely(userId: user.id, username: user.username, students: dataState.students)
        : null;

    if (student == null) {
      return const Scaffold(body: Center(child: Text('Student data not found')));
    }

    final allSubjects = dataState.subjects;
    final allGrades = dataState.grades;

    final allStudentGrades = allGrades.where((g) => g.studentId == student.id).toList();

    List<Grade> filteredGrades = List.from(allStudentGrades);

    if (_selectedSemester == 1) {
      filteredGrades = filteredGrades.where((g) => g.semester == 1).toList();
    } else if (_selectedSemester == 2) {
      filteredGrades = filteredGrades.where((g) => g.semester == 2).toList();
    }

    if (_selectedLevel != 0) {
      filteredGrades = filteredGrades.where((g) => g.level == _selectedLevel).toList();
    }

    filteredGrades.sort((a, b) => a.subjectName.compareTo(b.subjectName));

    // ✅ Fix: GPA من helpers.dart المشتركة
    final totalCredits = calculateEarnedCredits(filteredGrades, allSubjects);
    final subjectsPassed = filteredGrades.where((g) => g.total >= 50).length;
    final subjectsFailed = filteredGrades.where((g) => g.total < 50 && g.total > 0).length;
    final semesterGPA = calculateGPA(filteredGrades, allSubjects);
    final cumulativeGPA = calculateGPA(allStudentGrades, allSubjects);

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
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
              ),
              delegate: SliverChildListDelegate([
                _buildStatCard(
                  title: 'GPA',
                  value: '${getSemesterLabel()}: ${semesterGPA.toStringAsFixed(2)}\nC: ${cumulativeGPA.toStringAsFixed(2)}',
                  icon: Icons.trending_up,
                  color: const Color(0xFF8B5CF6),
                ),
                _buildStatCard(title: 'Total Credits', value: totalCredits.toString(), icon: Icons.credit_card, color: const Color(0xFF10B981)),
                _buildStatCard(title: 'Subjects Passed', value: subjectsPassed.toString(), icon: Icons.check_circle, color: const Color(0xFF34D399)),
                _buildStatCard(title: 'Subjects Failed', value: subjectsFailed.toString(), icon: Icons.cancel, color: const Color(0xFFF87171)),
              ]),
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
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedSemester,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
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
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedLevel,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                          icon: Icon(Icons.layers, color: Theme.of(context).primaryColor, size: 18),
                          items: [
                            const DropdownMenuItem(value: 0, child: Text('All Levels')),
                            ..._levels.map((l) => DropdownMenuItem(value: l, child: Text('Level $l'))),
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

          // Grades List
          if (filteredGrades.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No grades found', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('Try changing the filters', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: _buildGradeCard(filteredGrades[index], allSubjects),
                ),
                childCount: filteredGrades.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 9, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildGradeCard(Grade grade, List<Subject> subjects) {
    // ✅ Fix: بدل orElse: () => subjects.first
    final subject = findSubjectSafely(grade.subjectId, subjects);
    final isPassed = grade.isPassed;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grade.gradeColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showGradeDetails(grade, subject, subjects),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [grade.gradeColor, grade.gradeColor.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(grade.gradeLetter, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(grade.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '${subject?.code ?? 'N/A'} • ${subject?.doctorName ?? 'N/A'}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${grade.total.toInt()}/100', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: grade.gradeColor)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPassed ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isPassed ? 'Pass' : 'Fail', style: TextStyle(fontSize: 10, color: isPassed ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGradeDetails(Grade grade, Subject? subject, List<Subject> subjects) async {
    final effectiveSubject = subject ?? Subject(id: 0, name: grade.subjectName, doctorId: 0, doctorName: 'N/A', level: grade.level, semester: grade.semester);

    Map<String, double> distribution = {
      'midterm': 10, 'oral': 5, 'practical': 20,
      'attendance': 5, 'assignment': 10, 'final': 50,
    };

    final cacheKey = '${grade.doctorId}_${grade.subjectId}';
    if (_distributionsCache.containsKey(cacheKey)) {
      distribution = _distributionsCache[cacheKey]!;
    } else {
      final authState = context.read<AuthCubit>().state;
      if (authState.token != null) {
        final fetched = await ApiService.getGradeDistribution(grade.doctorId, grade.subjectId, authState.token!);
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 48, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(effectiveSubject.code ?? 'N/A', style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 4),
                  Text(grade.subjectName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(effectiveSubject.doctorName, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDistributionRow('Midterm Exam', grade.midterm, distribution['midterm'] ?? 0),
                    _buildDistributionRow('Oral Exam', grade.oral, distribution['oral'] ?? 0),
                    _buildDistributionRow('Practical Exam', grade.practical, distribution['practical'] ?? 0),
                    _buildDistributionRow('Attendance', grade.attendance, distribution['attendance'] ?? 0),
                    _buildDistributionRow('Assignment', grade.assignment, distribution['assignment'] ?? 0),
                    _buildDistributionRow('Final Exam', grade.finalExam, distribution['final'] ?? 0),
                    const Divider(height: 32),
                    _buildDistributionRow('Total', grade.total, 100, isTotal: true),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: grade.gradeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grade Letter', style: TextStyle(fontWeight: FontWeight.w500)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: grade.gradeColor, borderRadius: BorderRadius.circular(20)),
                            child: Text(grade.gradeLetter, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
    final color = isTotal ? Theme.of(context).primaryColor : Colors.grey.shade600;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: color)),
              Text('${earned.toInt()} / ${max.toInt()}', style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: color)),
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
        ],
      ),
    );
  }
}
