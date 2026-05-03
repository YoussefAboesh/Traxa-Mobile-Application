// lib/screens/sections/student/student_schedule.dart
// ✅ Fix: orElse → findStudentSafely
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';
import '../../../models/lecture.dart';
import '../../../core/helpers.dart';

class StudentSchedule extends StatefulWidget {
  const StudentSchedule({super.key});

  @override
  State<StudentSchedule> createState() => _StudentScheduleState();
}

class _StudentScheduleState extends State<StudentSchedule> {
  int _selectedTab = 0;
  String _searchQuery = '';
  int _selectedSemester = 0;
  String _selectedDay = '';

  final List<String> _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'];

  List<Subject> getFilteredSubjects(Student? student, List<Subject> allSubjects) {
    if (student == null) return [];
    List<Subject> filtered = allSubjects.where((s) => s.level == student.level && s.department == student.department).toList();
    if (_selectedSemester == 1) {
      filtered = filtered.where((s) => s.semester == 1).toList();
    // ignore: curly_braces_in_flow_control_structures
    } else if (_selectedSemester == 2) filtered = filtered.where((s) => s.semester == 2).toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) =>
        s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (s.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    return filtered;
  }

  List<Lecture> getFilteredLectures(Student? student, List<Subject> allSubjects, List<Lecture> allLectures) {
    if (student == null) return [];
    final studentSubjects = allSubjects.where((s) => s.level == student.level && s.department == student.department).toList();
    List<int> subjectIds;
    if (_selectedSemester == 0) {
      subjectIds = studentSubjects.map((s) => s.id).toList();
    } else {
      subjectIds = studentSubjects.where((s) => s.semester == _selectedSemester).map((s) => s.id).toList();
    }
    List<Lecture> filtered = allLectures.where((l) => subjectIds.contains(l.subjectId)).toList();
    if (_selectedDay.isNotEmpty) filtered = filtered.where((l) => l.day == _selectedDay).toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((l) =>
        l.subjectName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        l.doctorName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return filtered;
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
    final allLectures = dataState.lectures;
    final filteredSubjects = getFilteredSubjects(student, allSubjects);
    final semester1Subjects = filteredSubjects.where((s) => s.semester == 1).toList()..sort((a, b) => a.name.compareTo(b.name));
    final semester2Subjects = filteredSubjects.where((s) => s.semester == 2).toList()..sort((a, b) => a.name.compareTo(b.name));
    final filteredLectures = getFilteredLectures(student, allSubjects, allLectures);
    final Map<String, List<Lecture>> lecturesByDay = {};
    for (final day in _days) {
      lecturesByDay[day] = filteredLectures.where((l) => l.day == day).toList()..sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Tab Bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'Subjects', Icons.book_rounded, isDark),
                  _buildTabButton(1, 'Lectures', Icons.calendar_today_rounded, isDark),
                ],
              ),
            ),
          ),

          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Search
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _selectedTab == 0 ? 'Search subjects...' : 'Search lectures...',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor, size: 20),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Semester filter
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedSemester,
                              isExpanded: true,
                              dropdownColor: Theme.of(context).cardColor,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('All Semesters')),
                                DropdownMenuItem(value: 1, child: Text('Semester 1')),
                                DropdownMenuItem(value: 2, child: Text('Semester 2')),
                              ],
                              onChanged: (v) => setState(() => _selectedSemester = v ?? 0),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedTab == 1) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedDay.isEmpty ? null : _selectedDay,
                                hint: const Text('All Days', style: TextStyle(fontSize: 13)),
                                isExpanded: true,
                                dropdownColor: Theme.of(context).cardColor,
                                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('All Days')),
                                  ..._days.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                                ],
                                onChanged: (v) => setState(() => _selectedDay = v ?? ''),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Content
          if (_selectedTab == 0)
            _buildSubjectsContent(semester1Subjects, semester2Subjects, isDark)
          else
            _buildLecturesContent(lecturesByDay),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, bool isDark) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isActive ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600))),
            ],
          ),
        ),
      ),
    );
  }

  SliverList _buildSubjectsContent(List<Subject> sem1, List<Subject> sem2, bool isDark) {
    return SliverList(
      delegate: SliverChildListDelegate([
        if (sem1.isNotEmpty) _buildSemesterSection('Semester 1', sem1, isDark),
        if (sem2.isNotEmpty) _buildSemesterSection('Semester 2', sem2, isDark),
        if (sem1.isEmpty && sem2.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('No subjects found', style: TextStyle(color: Color(0xFF94A3B8)))),
          ),
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildSemesterSection(String title, List<Subject> subjects, bool isDark) {
    final totalCredits = subjects.fold<int>(0, (sum, s) => sum + s.totalCreditHours);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${subjects.length} subjects • $totalCredits credits', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
              ],
            ),
          ),
          ...subjects.map((s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(s.code ?? 'N/A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor))),
                Expanded(child: Text(s.name, style: const TextStyle(fontSize: 12))),
                Text(s.doctorName, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('${s.totalCreditHours}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  SliverList _buildLecturesContent(Map<String, List<Lecture>> lecturesByDay) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    return SliverList(
      delegate: SliverChildListDelegate([
        ...daysToShow.map((day) {
          final dayLectures = lecturesByDay[day] ?? [];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF8B5CF6).withValues(alpha: 0.08), const Color(0xFF6366F1).withValues(alpha: 0.04)]),
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: Theme.of(context).primaryColor, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(day, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text('${dayLectures.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF8B5CF6))),
                      ),
                    ],
                  ),
                ),
                if (dayLectures.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No lectures', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600))))
                else
                  ...dayLectures.map((l) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _buildLectureCard(l))),
                const SizedBox(height: 8),
              ],
            ),
          );
        }),
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildLectureCard(Lecture lecture) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 3, height: 40, decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.subjectName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(lecture.doctorName, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 10, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(lecture.timeDisplay, style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600)),
                    const SizedBox(width: 10),
                    Icon(Icons.location_on, size: 10, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Flexible(child: Text(lecture.locationName, style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
