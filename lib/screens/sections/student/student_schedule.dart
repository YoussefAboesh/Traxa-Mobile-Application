// lib/screens/sections/student/student_schedule.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';
import '../../../models/lecture.dart';

class StudentSchedule extends StatefulWidget {
  const StudentSchedule({super.key});

  @override
  State<StudentSchedule> createState() => _StudentScheduleState();
}

class _StudentScheduleState extends State<StudentSchedule> {
  int _selectedTab = 0; // 0 = Subjects, 1 = Lectures
  String _searchQuery = '';
  int _selectedSemester = 0; // 0 = All, 1 = Semester 1, 2 = Semester 2
  String _selectedDay = ''; // '' = All

  final List<String> _days = [
    'Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'
  ];

  // جلب المواد الخاصة بالطالب مع فلترة حسب السيمستر
  List<Subject> getFilteredSubjects(Student? student, List<Subject> allSubjects) {
    if (student == null) return [];
    
    List<Subject> filtered = allSubjects.where((s) =>
      s.level == student.level &&
      s.department == student.department
    ).toList();
    
    if (_selectedSemester == 1) {
      filtered = filtered.where((s) => s.semester == 1).toList();
    } else if (_selectedSemester == 2) {
      filtered = filtered.where((s) => s.semester == 2).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) =>
        s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (s.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    return filtered;
  }

  // جلب المحاضرات المرتبطة بمواد في سيمستر معين
  List<Lecture> getFilteredLectures(Student? student, List<Subject> allSubjects, List<Lecture> allLectures) {
    if (student == null) return [];
    
    // جلب المواد الخاصة بالطالب
    final studentSubjects = allSubjects.where((s) =>
      s.level == student.level &&
      s.department == student.department
    ).toList();
    
    // جلب IDs المواد حسب السيمستر المختار
    List<int> subjectIds;
    if (_selectedSemester == 0) {
      // كل المواد
      subjectIds = studentSubjects.map((s) => s.id).toList();
    } else {
      // مواد سيمستر معين
      subjectIds = studentSubjects
          .where((s) => s.semester == _selectedSemester)
          .map((s) => s.id)
          .toList();
    }
    
    // تصفية المحاضرات
    List<Lecture> filtered = allLectures.where((l) => 
      subjectIds.contains(l.subjectId)
    ).toList();
    
    // فلترة حسب اليوم
    if (_selectedDay.isNotEmpty) {
      filtered = filtered.where((l) => l.day == _selectedDay).toList();
    }
    
    // فلترة حسب البحث
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
    Student? student;

    if (user != null && dataState.students.isNotEmpty) {
      student = dataState.students.firstWhere(
        (s) => s.id == user.id || s.studentId == user.username,
        orElse: () => dataState.students.first,
      );
    }

    final allSubjects = dataState.subjects;
    final allLectures = dataState.lectures;
    
    // جلب المواد المفلترة
    final filteredSubjects = getFilteredSubjects(student, allSubjects);
    
    // تجميع المواد حسب السيمستر
    final semester1Subjects = filteredSubjects.where((s) => s.semester == 1).toList();
    final semester2Subjects = filteredSubjects.where((s) => s.semester == 2).toList();
    
    semester1Subjects.sort((a, b) => a.name.compareTo(b.name));
    semester2Subjects.sort((a, b) => a.name.compareTo(b.name));

    // جلب المحاضرات المفلترة
    final filteredLectures = getFilteredLectures(student, allSubjects, allLectures);
    
    // تجميع المحاضرات حسب اليوم
    final Map<String, List<Lecture>> lecturesByDay = {};
    for (final day in _days) {
      lecturesByDay[day] = filteredLectures.where((l) => l.day == day).toList();
      lecturesByDay[day]!.sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
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
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 
                              ? Theme.of(context).primaryColor 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(36),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_rounded,
                              size: 16,
                              color: _selectedTab == 0 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Subjects',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _selectedTab == 0 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 
                              ? Theme.of(context).primaryColor 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(36),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: _selectedTab == 1 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lectures',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _selectedTab == 1 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Filter Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _selectedTab == 0 ? 'Search subjects...' : 'Search lectures...',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500, fontSize: 12),
                      prefixIcon: Icon(Icons.search, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, size: 16),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark 
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Semester Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark 
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedSemester,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).cardColor,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 12),
                        icon: Icon(Icons.arrow_drop_down, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('All Semesters')),
                          DropdownMenuItem(value: 1, child: Text('Semester 1')),
                          DropdownMenuItem(value: 2, child: Text('Semester 2')),
                        ],
                        onChanged: (value) => setState(() => _selectedSemester = value ?? 0),
                      ),
                    ),
                  ),
                  
                  // Day Dropdown (only for Lectures tab)
                  if (_selectedTab == 1) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark 
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDay.isEmpty ? null : _selectedDay,
                          isExpanded: true,
                          hint: Text('All Days', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 12)),
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 12),
                          icon: Icon(Icons.arrow_drop_down, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Days')),
                            ..._days.map((day) => DropdownMenuItem(value: day, child: Text(day))),
                          ],
                          onChanged: (value) => setState(() => _selectedDay = value ?? ''),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          
          // Content - Subjects or Lectures
          if (_selectedTab == 0)
            _buildSubjectsContent(semester1Subjects, semester2Subjects)
          else
            _buildLecturesContent(lecturesByDay),
          
          // Extra bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  SliverList _buildSubjectsContent(List<Subject> semester1, List<Subject> semester2) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SliverList(
      delegate: SliverChildListDelegate([
        if (semester1.isNotEmpty && (_selectedSemester == 0 || _selectedSemester == 1))
          _buildSubjectSection('Semester 1', semester1),
        if (semester2.isNotEmpty && (_selectedSemester == 0 || _selectedSemester == 2))
          const SizedBox(height: 16),
        if (semester2.isNotEmpty && (_selectedSemester == 0 || _selectedSemester == 2))
          _buildSubjectSection('Semester 2', semester2),
        if (semester1.isEmpty && semester2.isEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                'No subjects found',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildSubjectSection(String title, List<Subject> subjects) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${subjects.length} subjects',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark 
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('DOCTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                      ),
                      SizedBox(
                        width: 55,
                        child: Text('CREDITS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)), textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
                
                ...subjects.asMap().entries.map((entry) {
                  final subject = entry.value;
                  final isLast = entry.key == subjects.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      border: !isLast
                          ? Border(
                              bottom: BorderSide(color: isDark 
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade200),
                            )
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            subject.code ?? 'N/A',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              subject.name,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              subject.doctorName,
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 55,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${subject.creditHours}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  SliverList _buildLecturesContent(Map<String, List<Lecture>> lecturesByDay) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // إظهار كل الأيام (حتى التي لا تحتوي على محاضرات)
    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    
    return SliverList(
      delegate: SliverChildListDelegate(
        daysToShow.map((day) {
          final dayLectures = lecturesByDay[day] ?? [];
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  const Color(0xFF6366F1).withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: Theme.of(context).primaryColor, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${dayLectures.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (dayLectures.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No lectures',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  )
                else
                  ...dayLectures.map((lecture) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _buildLectureCard(lecture),
                  )),
                const SizedBox(height: 8),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLectureCard(Lecture lecture) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lecture.subjectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  lecture.doctorName,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 10, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(
                      lecture.timeDisplay,
                      style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.location_on, size: 10, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(
                      lecture.locationName,
                      style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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