// lib/screens/sections/student/student_schedule.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';
import '../../../models/lecture.dart';
import '../../../models/section.dart';
import '../../../core/helpers.dart';

class StudentSchedule extends StatefulWidget {
  const StudentSchedule({super.key});

  @override
  State<StudentSchedule> createState() => _StudentScheduleState();
}

class _StudentScheduleState extends State<StudentSchedule> {
  // Tabs: 0=Subjects, 1=Lectures, 2=Sections
  int _selectedTab = 0;
  String _searchQuery = '';
  String _selectedDay = '';
  bool _isRefreshing = false;

  final List<String> _days = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday'
  ];

  Future<void> _refreshSchedule() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<DataCubit>().loadAllData();
    } catch (e) {
      print('Error refreshing schedule: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<Subject> getFilteredSubjects(
      Student? student, List<Subject> allSubjects, int currentSemester) {
    if (student == null) return [];
    List<Subject> filtered = allSubjects
        .where((s) =>
            s.level == student.level &&
            s.department == student.department &&
            s.semester == currentSemester)
        .toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (s.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }
    return filtered;
  }

  List<Lecture> getFilteredLectures(Student? student, List<Subject> allSubjects,
      List<Lecture> allLectures, int currentSemester) {
    if (student == null) return [];
    final subjectIds = allSubjects
        .where((s) =>
            s.level == student.level &&
            s.department == student.department &&
            s.semester == currentSemester)
        .map((s) => s.id)
        .toList();

    List<Lecture> filtered =
        allLectures.where((l) => subjectIds.contains(l.subjectId)).toList();
    if (_selectedDay.isNotEmpty) {
      filtered = filtered.where((l) => l.day == _selectedDay).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((l) =>
              l.subjectName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              l.doctorName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return filtered;
  }

  List<Section> getFilteredSections(
      Student? student, List<Section> allSections) {
    if (student == null) return [];
    List<Section> filtered = allSections
        .where((s) =>
            s.level == student.level &&
            (s.department == null || s.department == student.department))
        .toList();
    if (_selectedDay.isNotEmpty) {
      filtered = filtered.where((s) => s.day == _selectedDay).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.subjectName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              s.taName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;
    final currentSemester = dataState.currentSemester;

    final student = (user != null)
        ? findStudentSafely(
            userId: user.id,
            username: user.username,
            students: dataState.students)
        : null;

    if (student == null) {
      return const Scaffold(
          body: Center(child: Text('Student data not found')));
    }

    final allSubjects = dataState.allSubjects;
    final allLectures = dataState.allLectures;
    final allSections = dataState.allSections; // List<Section>

    final filteredSubjects =
        getFilteredSubjects(student, allSubjects, currentSemester);
    final semester1Subjects = filteredSubjects
        .where((s) => s.semester == 1)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final semester2Subjects = filteredSubjects
        .where((s) => s.semester == 2)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final filteredLectures =
        getFilteredLectures(student, allSubjects, allLectures, currentSemester);
    final Map<String, List<Lecture>> lecturesByDay = {};
    for (final day in _days) {
      lecturesByDay[day] = filteredLectures.where((l) => l.day == day).toList()
        ..sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
    }

    final filteredSections = getFilteredSections(student, allSections);
    final Map<String, List<Section>> sectionsByDay = {};
    for (final day in _days) {
      sectionsByDay[day] = filteredSections.where((s) => s.day == day).toList()
        ..sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshSchedule,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            // ── Tab Bar (Subjects / Lectures / Sections) ──────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Subjects', Icons.book_rounded, isDark),
                    _buildTabButton(
                        1, 'Lectures', Icons.school_rounded, isDark),
                    _buildTabButton(
                        2, 'Sections', Icons.groups_rounded, isDark),
                  ],
                ),
              ),
            ),

            // ── Filters ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Semester banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Showing data for Semester $currentSemester',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _selectedTab == 0
                            ? 'Search subjects...'
                            : _selectedTab == 1
                                ? 'Search lectures...'
                                : 'Search sections...',
                        hintStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade500,
                            fontSize: 13),
                        prefixIcon: Icon(Icons.search,
                            color: Theme.of(context).primaryColor, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Day filter (for lectures & sections)
                    if (_selectedTab == 1 || _selectedTab == 2)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDay.isEmpty
                                      ? null
                                      : _selectedDay,
                                  hint: const Text('All Days',
                                      style: TextStyle(fontSize: 13)),
                                  isExpanded: true,
                                  dropdownColor: Theme.of(context).cardColor,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                      fontSize: 13),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '', child: Text('All Days')),
                                    ..._days.map((d) => DropdownMenuItem(
                                        value: d, child: Text(d))),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedDay = v ?? ''),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            if (_selectedTab == 0)
              _buildSubjectsContent(
                  semester1Subjects, semester2Subjects, isDark, allSubjects)
            else if (_selectedTab == 1)
              _buildLecturesContent(lecturesByDay)
            else
              _buildSectionsContent(sectionsByDay),
          ],
        ),
      ),
    );
  }

  // ── Tab Button ────────────────────────────────────────────────────────────
  Widget _buildTabButton(int index, String label, IconData icon, bool isDark) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTab = index;
          _searchQuery = '';
          _selectedDay = '';
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color:
                isActive ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : Colors.grey.shade600)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isActive
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600))),
            ],
          ),
        ),
      ),
    );
  }

  // ── Subjects Content ──────────────────────────────────────────────────────
  SliverList _buildSubjectsContent(List<Subject> sem1, List<Subject> sem2,
      bool isDark, List<Subject> allSubjects) {
    return SliverList(
      delegate: SliverChildListDelegate([
        if (sem1.isNotEmpty)
          _buildSemesterSection('Semester 1', sem1, isDark, allSubjects),
        if (sem2.isNotEmpty)
          _buildSemesterSection('Semester 2', sem2, isDark, allSubjects),
        if (sem1.isEmpty && sem2.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
                child: Text('No subjects found',
                    style: TextStyle(color: Color(0xFF94A3B8)))),
          ),
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildSemesterSection(String title, List<Subject> subjects,
      bool isDark, List<Subject> allSubjects) {
    final totalCredits =
        subjects.fold<int>(0, (sum, s) => sum + s.totalCreditHours);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${subjects.length} subjects • $totalCredits credits',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                    width: 55,
                    child: Text('Code',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8)))),
                const Expanded(
                    child: Text('Subject',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8)))),
                const SizedBox(
                    width: 80,
                    child: Text('Doctor',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8)))),
                const SizedBox(
                    width: 55,
                    child: Text('TA',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8)))),
                const SizedBox(
                    width: 30,
                    child: Text('Hrs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8)))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...subjects.map((s) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: _buildSubjectRow(s, isDark),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(Subject s, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 55,
          child: Text(s.code ?? 'N/A',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor)),
        ),
        Expanded(
          child: Text(s.name,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        SizedBox(
          width: 80,
          child: Text(
            s.doctorName,
            style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        SizedBox(
          width: 55,
          child: Text(
            s.taName ?? 'N/A',
            style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        SizedBox(
          width: 30,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${s.totalCreditHours}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Color(0xFF8B5CF6))),
            ),
          ),
        ),
      ],
    );
  }

  // ── Lectures Content ──────────────────────────────────────────────────────
  SliverList _buildLecturesContent(Map<String, List<Lecture>> lecturesByDay) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    return SliverList(
      delegate: SliverChildListDelegate([
        ...daysToShow.map((day) {
          final dayLectures = lecturesByDay[day] ?? [];
          return _buildDayContainer(
            context,
            day: day,
            count: dayLectures.length,
            isDark: isDark,
            isEmpty: dayLectures.isEmpty,
            emptyMsg: 'No lectures',
            children: dayLectures
                .map((l) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: _buildLectureCard(l),
                    ))
                .toList(),
            accentColor: Theme.of(context).primaryColor,
          );
        }),
        const SizedBox(height: 100),
      ]),
    );
  }

  // ── Sections Content ──────────────────────────────────────────────────────
  SliverList _buildSectionsContent(Map<String, List<Section>> sectionsByDay) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    return SliverList(
      delegate: SliverChildListDelegate([
        ...daysToShow.map((day) {
          final daySections = sectionsByDay[day] ?? [];
          return _buildDayContainer(
            context,
            day: day,
            count: daySections.length,
            isDark: isDark,
            isEmpty: daySections.isEmpty,
            emptyMsg: 'No sections',
            children: daySections
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: _buildSectionCard(s),
                    ))
                .toList(),
            accentColor: const Color(0xFF10B981),
          );
        }),
        const SizedBox(height: 100),
      ]),
    );
  }

  // ── Day Container ─────────────────────────────────────────────────────────
  Widget _buildDayContainer(
    BuildContext context, {
    required String day,
    required int count,
    required bool isDark,
    required bool isEmpty,
    required String emptyMsg,
    required List<Widget> children,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.08),
              accentColor.withValues(alpha: 0.03),
            ]),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF1E293B))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$count',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: accentColor)),
                ),
              ],
            ),
          ),
          if (isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                    child: Text(emptyMsg,
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600))))
          else
            ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Lecture Card ──────────────────────────────────────────────────────────
  Widget _buildLectureCard(Lecture lecture) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 48,
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.subjectName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.school_rounded,
                      size: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text(lecture.doctorName,
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600)),
                ]),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 10,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(lecture.timeDisplay,
                        style: TextStyle(
                            fontSize: 9,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600)),
                    const SizedBox(width: 10),
                    Icon(Icons.location_on,
                        size: 10,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Flexible(
                        child: Text(lecture.locationName,
                            style: TextStyle(
                                fontSize: 9,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Lec',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  // ── Section Card ──────────────────────────────────────────────────────────
  Widget _buildSectionCard(Section section) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const sectionColor = Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 48,
              decoration: BoxDecoration(
                  color: sectionColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.subjectName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.school_rounded,
                      size: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text(section.taName,
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600)),
                ]),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 10,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(section.timeDisplay,
                        style: TextStyle(
                            fontSize: 9,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600)),
                    const SizedBox(width: 10),
                    Icon(Icons.location_on,
                        size: 10,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Flexible(
                        child: Text(section.locationName,
                            style: TextStyle(
                                fontSize: 9,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: sectionColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Sec',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: sectionColor)),
          ),
        ],
      ),
    );
  }
}
