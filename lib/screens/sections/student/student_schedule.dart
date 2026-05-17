// lib/screens/sections/student/student_schedule.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';
import '../../../models/lecture.dart';
import '../../../models/section.dart';
import '../../../models/teaching_assistant.dart';
import '../../../core/helpers.dart';
import '../../../core/theme.dart';
import '../../../widgets/app_skeleton.dart';

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
      // loadAllData يحمّل المعيدين كمان، فاسم المعيد بيتحل فوراً.
      await context.read<DataCubit>().loadAllData();
    } catch (e) {
      print('Error refreshing schedule: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// يحلّ اسم المعيد للسكشن فوراً من البيانات المحمّلة (من غير أي API call).
  String _resolveSectionTAName(
    Section section,
    List<TeachingAssistant> tas,
    List<Subject> subjects,
  ) {
    // 1) الاسم جاي مع السكشن نفسه
    final fromSection = section.taName.trim();
    if (fromSection.isNotEmpty && fromSection.toLowerCase() != 'ta') {
      return fromSection;
    }
    // 2) من قائمة المعيدين عن طريق ta_id
    if (section.taId != null) {
      final m = tas.where((t) => t.id == section.taId).toList();
      if (m.isNotEmpty && m.first.name.trim().isNotEmpty) {
        return m.first.name;
      }
    }
    // 3) من المعيد المربوط بالمادة
    final subj = subjects.where((s) => s.id == section.subjectId).toList();
    if (subj.isNotEmpty) {
      final tn = subj.first.taName?.trim();
      if (tn != null &&
          tn.isNotEmpty &&
          tn.toLowerCase() != 'not assigned') {
        return tn;
      }
    }
    return 'TA';
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
      Student? student,
      List<Section> allSections,
      List<Subject> allSubjects,
      int currentSemester) {
    if (student == null) return [];

    // Sections don't carry a semester field, so resolve it from the
    // linked subject and only keep sections of the current semester.
    final Map<int, int> semesterBySubject = {
      for (final s in allSubjects) s.id: s.semester
    };

    List<Section> filtered = allSections.where((s) {
      if (s.level != student.level) return false;
      if (s.department != null && s.department != student.department) {
        return false;
      }
      final subjectSemester = semesterBySubject[s.subjectId];
      // If the subject is known, enforce the current semester.
      if (subjectSemester != null && subjectSemester != currentSemester) {
        return false;
      }
      return true;
    }).toList();
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
    final isDark = context.isDarkMode;
    final user = authState.user;
    final currentSemester = dataState.currentSemester;

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
    final allLectures = dataState.allLectures;
    final allSections = dataState.allSections;

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

    final filteredSections =
        getFilteredSections(student, allSections, allSubjects, currentSemester);
    final Map<String, List<Section>> sectionsByDay = {};
    for (final day in _days) {
      sectionsByDay[day] = filteredSections.where((s) => s.day == day).toList()
        ..sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSkeleton(
        enabled: showSkeleton,
        child: RefreshIndicator(
        onRefresh: _refreshSchedule,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            // Tab Bar
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(40.r),
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

            // Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    // Semester banner
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16.sp, color: Theme.of(context).primaryColor),
                          SizedBox(width: 8.w),
                          Text(
                            'Showing data for Semester $currentSemester',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Search
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          fontSize: 14.sp),
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
                            fontSize: 13.sp),
                        prefixIcon: Icon(Icons.search,
                            color: Theme.of(context).primaryColor, size: 20.sp),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 12.h),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Day filter (for lectures & sections)
                    if (_selectedTab == 1 || _selectedTab == 2)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 10.w),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDay.isEmpty
                                      ? null
                                      : _selectedDay,
                                  hint: Text('All Days',
                                      style: TextStyle(fontSize: 13.sp)),
                                  isExpanded: true,
                                  dropdownColor: Theme.of(context).cardColor,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                      fontSize: 13.sp),
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
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),

            // Content
            if (_selectedTab == 0)
              _buildSubjectsContent(
                  semester1Subjects, semester2Subjects, isDark)
            else if (_selectedTab == 1)
              _buildLecturesContent(lecturesByDay, isDark)
            else
              _buildSectionsContent(sectionsByDay, isDark,
                  dataState.teachingAssistants, allSubjects),
          ],
        ),
      ),
      ),
    );
  }

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
          padding: EdgeInsets.symmetric(vertical: 9.h),
          decoration: BoxDecoration(
            color:
                isActive ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(36.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14.sp,
                  color: isActive
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : Colors.grey.shade600)),
              SizedBox(width: 4.w),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
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

  // ==================== MODERN SUBJECTS TABLE ====================

  SliverList _buildSubjectsContent(
      List<Subject> sem1, List<Subject> sem2, bool isDark) {
    return SliverList(
      delegate: SliverChildListDelegate([
        if (sem1.isNotEmpty)
          _buildModernSemesterCard('Semester 1', sem1, isDark),
        if (sem2.isNotEmpty)
          _buildModernSemesterCard('Semester 2', sem2, isDark),
        if (sem1.isEmpty && sem2.isEmpty)
          Padding(
            padding: EdgeInsets.all(40.r),
            child: const Center(
                child: Text('No subjects found',
                    style: TextStyle(color: Color(0xFF94A3B8)))),
          ),
        SizedBox(height: 100.h),
      ]),
    );
  }

  Widget _buildModernSemesterCard(String title, List<Subject> subjects, bool isDark) {
    final totalCredits = subjects.fold<int>(0, (sum, s) => sum + s.totalCreditHours);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10.r,
                  offset: Offset(0, 2.h),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        title == 'Semester 1' ? Icons.looks_one : Icons.looks_two,
                        size: 18.sp,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${subjects.length} subjects • $totalCredits credits',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70.w,
                  child: Text(
                    'CODE',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SUBJECT',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'DOCTOR',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 45.w,
                  child: Center(
                    child: Text(
                      'HRS',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subjects Rows
          Column(
            children: subjects.asMap().entries.map((entry) {
              final index = entry.key;
              final subject = entry.value;
              final isLast = index == subjects.length - 1;

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? (index.isEven ? const Color(0xFF1E293B) : const Color(0xFF1A2538))
                      : (index.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                  border: !isLast
                      ? Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code Column
                    SizedBox(
                      width: 50.w,
                      child: Text(
                        subject.code ?? 'N/A',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: true,
                      ),
                    ),
                    // Subject Column
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: Text(
                          subject.name,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                      ),
                    ),
                    // Doctor Column
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: Text(
                          subject.doctorName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                      ),
                    ),
                    // Hours Column
                    SizedBox(
                      width: 45.w,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '${subject.totalCreditHours}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  SliverList _buildLecturesContent(Map<String, List<Lecture>> lecturesByDay, bool isDark) {
    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    return SliverList(
      delegate: SliverChildListDelegate([
        ...daysToShow.map((day) {
          final dayLectures = lecturesByDay[day] ?? [];
          return _buildDayContainer(
            day: day,
            count: dayLectures.length,
            isDark: isDark,
            isEmpty: dayLectures.isEmpty,
            emptyMsg: 'No lectures',
            children: dayLectures
                .map((l) => Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 4.h),
                      child: _buildLectureCard(l, isDark),
                    ))
                .toList(),
            accentColor: Theme.of(context).primaryColor,
          );
        }),
        SizedBox(height: 100.h),
      ]),
    );
  }

  SliverList _buildSectionsContent(
    Map<String, List<Section>> sectionsByDay,
    bool isDark,
    List<TeachingAssistant> tas,
    List<Subject> subjects,
  ) {
    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    return SliverList(
      delegate: SliverChildListDelegate([
        ...daysToShow.map((day) {
          final daySections = sectionsByDay[day] ?? [];
          return _buildDayContainer(
            day: day,
            count: daySections.length,
            isDark: isDark,
            isEmpty: daySections.isEmpty,
            emptyMsg: 'No sections',
            children: daySections
                .map((s) => Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 4.h),
                      child: _buildSectionCard(
                          s, isDark, _resolveSectionTAName(s, tas, subjects)),
                    ))
                .toList(),
            accentColor: const Color(0xFF10B981),
          );
        }),
        SizedBox(height: 100.h),
      ]),
    );
  }

  Widget _buildDayContainer({
    required String day,
    required int count,
    required bool isDark,
    required bool isEmpty,
    required String emptyMsg,
    required List<Widget> children,
    required Color accentColor,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.08),
              accentColor.withValues(alpha: 0.03),
            ]),
        borderRadius: BorderRadius.circular(16.r),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day,
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B))),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r)),
                  child: Text('$count',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                          color: accentColor)),
                ),
              ],
            ),
          ),
          if (isEmpty)
            Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Center(
                    child: Text(emptyMsg,
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600))))
          else
            ...children,
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildLectureCard(Lecture lecture, bool isDark) {
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
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Container(
              width: 3.w,
              height: 48.h,
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(2.r))),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lecture.subjectName,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Row(children: [
                  Icon(Icons.school_rounded,
                      size: 10.sp, color: subTextColor),
                  SizedBox(width: 3.w),
                  Text(lecture.doctorName,
                      style: TextStyle(fontSize: 10.sp, color: subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 10.sp, color: subTextColor),
                    SizedBox(width: 2.w),
                    Text(lecture.timeDisplay,
                        style: TextStyle(fontSize: 9.sp, color: subTextColor)),
                    SizedBox(width: 10.w),
                    Icon(Icons.location_on,
                        size: 10.sp, color: subTextColor),
                    SizedBox(width: 2.w),
                    Flexible(
                        child: Text(lecture.locationName,
                            style: TextStyle(fontSize: 9.sp, color: subTextColor),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text('Lec',
                style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(Section section, bool isDark, String taName) {
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.shade100;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
    const sectionColor = Color(0xFF10B981);

    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Container(
              width: 3.w,
              height: 48.h,
              decoration: BoxDecoration(
                  color: sectionColor, borderRadius: BorderRadius.circular(2.r))),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.subjectName,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Row(children: [
                  Icon(Icons.school_rounded,
                      size: 10.sp, color: subTextColor),
                  SizedBox(width: 3.w),
                  Flexible(
                    child: Text(
                      taName,
                      style: TextStyle(fontSize: 10.sp, color: subTextColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ]),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 10.sp, color: subTextColor),
                    SizedBox(width: 2.w),
                    Text(section.timeDisplay,
                        style: TextStyle(fontSize: 9.sp, color: subTextColor)),
                    SizedBox(width: 10.w),
                    Icon(Icons.location_on,
                        size: 10.sp, color: subTextColor),
                    SizedBox(width: 2.w),
                    Flexible(
                        child: Text(section.locationName,
                            style: TextStyle(fontSize: 9.sp, color: subTextColor),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: sectionColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text('Sec',
                style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: sectionColor)),
          ),
        ],
      ),
    );
  }
}
