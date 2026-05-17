// lib/screens/sections/doctor/doctor_subjects.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/subject.dart';
import '../../../models/teaching_assistant.dart';
import '../../../core/theme.dart';
import '../../../widgets/app_skeleton.dart';

class DoctorSubjects extends StatefulWidget {
  const DoctorSubjects({super.key});

  @override
  State<DoctorSubjects> createState() => _DoctorSubjectsState();
}

class _DoctorSubjectsState extends State<DoctorSubjects> {
  String _searchQuery = '';
  int _selectedLevel = 0;
  bool _showFilters = true;
  bool _isRefreshing = false;

  final List<int> _levels = [1, 2, 3, 4];

  Future<void> _refreshSubjects() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await context.read<DataCubit>().loadAllData();
    } catch (e) {
      print('Error refreshing subjects: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = context.isDarkMode;
    final currentSemester = dataState.currentSemester;

    final user = authState.user;

    final isTA = user?.isTeachingAssistant ?? false;

    List<Subject> doctorSubjects = [];
    List<TeachingAssistant> allTAs = dataState.teachingAssistants;

    print('🔍 DEBUG: currentSemester = $currentSemester');
    print('🔍 DEBUG: dataState.subjects count = ${dataState.subjects.length}');
    print('🔍 DEBUG: allTAs count = ${allTAs.length}');

    if (isTA) {
      // =========================
      // TA SUBJECTS
      // =========================
      // المعيد: المواد اللي ليه سكاشن فيها (في الترم الحالي)
      final loggedUserId = user?.id ?? 0;

      final taSubjectIds = dataState.allSections
          .where((sec) => sec.taId == loggedUserId)
          .map((sec) => sec.subjectId)
          .toSet();

      doctorSubjects = dataState.subjects
          .where((subject) => taSubjectIds.contains(subject.id))
          .toList();

      print('✅ TA Sections subjects => ${doctorSubjects.length}');
    } else {
      // =========================
      // DOCTOR SUBJECTS
      // =========================
      final doctorId = user?.effectiveDoctorId ?? user?.id ?? 0;

      doctorSubjects = dataState.subjects.where((subject) {
        return subject.doctorId == doctorId;
      }).toList();

      print('👨‍⚕️ Doctor Subjects => ${doctorSubjects.length}');
    }

    // فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      doctorSubjects = doctorSubjects
          .where((s) =>
              s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (s.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    // فلترة حسب المستوى
    if (_selectedLevel != 0) {
      doctorSubjects =
          doctorSubjects.where((s) => s.level == _selectedLevel).toList();
    }

    // تجميع المواد حسب المستوى
    final Map<int, List<Subject>> subjectsByLevel = {};
    for (final level in _levels) {
      final levelSubjects =
          doctorSubjects.where((s) => s.level == level).toList();
      if (levelSubjects.isNotEmpty) {
        subjectsByLevel[level] = levelSubjects;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSkeleton(
        enabled: dataState.loadingState.isLoading,
        child: RefreshIndicator(
        onRefresh: _refreshSubjects,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            // Header with semester info
            SliverAppBar(
              title: const Text('My Subjects'),
              centerTitle: false,
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              actions: [
                Container(
                  margin: EdgeInsets.only(right: 16.w),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'S$currentSemester',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),

            // Search and Filters
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16.r),
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    // Search Field
                    TextField(
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 13.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search subjects...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF64748B)
                              : Colors.grey.shade500,
                          fontSize: 12.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                          size: 18.sp,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey.shade600,
                                  size: 18.sp,
                                ),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 10.h),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),

                    SizedBox(height: 12.h),

                    // Filter Row
                    Row(
                      children: [
                        // Filter button
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showFilters = !_showFilters),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: _showFilters
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.2)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: _showFilters
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.5)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showFilters
                                      ? Icons.filter_alt
                                      : Icons.filter_alt_outlined,
                                  size: 16.sp,
                                  color: _showFilters
                                      ? Theme.of(context).primaryColor
                                      : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : Colors.grey.shade600),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Filter',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: _showFilters
                                        ? Theme.of(context).primaryColor
                                        : (isDark
                                            ? const Color(0xFF94A3B8)
                                            : Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Level Dropdown — يظهر/يختفي حسب زرار الفلتر
                        if (_showFilters) ...[
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Container(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 10.w),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20.r),
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
                                    fontSize: 12.sp,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : Colors.grey.shade600,
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                        value: 0, child: Text('All Levels')),
                                    ..._levels.map((level) => DropdownMenuItem(
                                          value: level,
                                          child: Text('Level $level'),
                                        )),
                                  ],
                                  onChanged: (value) => setState(
                                      () => _selectedLevel = value ?? 0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Subjects List by Level
            if (subjectsByLevel.isNotEmpty)
              SliverList(
                delegate: SliverChildListDelegate(
                  subjectsByLevel.keys.map((level) {
                    final levelSubjects = subjectsByLevel[level]!;
                    levelSubjects.sort((a, b) => a.name.compareTo(b.name));

                    return Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Level Header
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 10.h, horizontal: 16.w),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Level $level',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    '${levelSubjects.length} subjects',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // Subjects table
                          _buildSubjectsTable(levelSubjects, allTAs, isTA),

                          SizedBox(height: 8.h),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Empty state
            if (subjectsByLevel.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(16.r),
                  padding: EdgeInsets.all(40.r),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.book,
                            size: 48.sp,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade400),
                        SizedBox(height: 16.h),
                        Text(
                          isTA
                              ? 'No subjects assigned to you for Semester $currentSemester'
                              : 'No subjects for Semester $currentSemester',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600,
                            fontSize: 16.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          isTA
                              ? 'Subjects will appear when assigned by the professor for this semester'
                              : 'Subjects will appear when assigned in the current semester',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            SliverPadding(padding: EdgeInsets.only(bottom: 80.h)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSubjectsTable(List<Subject> subjects, List<TeachingAssistant> allTAs, bool isTA) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve the TA name for a subject. The enriched /api/subjects-public
    // endpoint already joins `ta_name`, so prefer that; only fall back to the
    // TA list lookup when the name didn't come with the subject.
    String getTAName(Subject subject) {
      if (subject.taName != null && subject.taName!.trim().isNotEmpty) {
        return subject.taName!;
      }
      if (subject.taId == null) return 'Not Assigned';

      final ta = allTAs.firstWhere(
        (t) => t.id == subject.taId,
        orElse: () => TeachingAssistant(
          id: 0,
          name: 'Not Assigned',
          username: '',
          assignedSubjectIds: [],
        ),
      );
      return ta.name;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.r),
                topRight: Radius.circular(14.r),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'CODE',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 6,
                  child: Text(
                    'SUBJECT NAME',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 7,
                  child: Text(
                    isTA ? 'DOCTOR' : 'TA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 5,
                  child: Text(
                    'DEPARTMENT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ...subjects.asMap().entries.map((entry) {
            final subject = entry.value;
            final isLast = entry.key == subjects.length - 1;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: !isLast
                    ? Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade200,
                        ),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Code
                  Expanded(
                    flex: 4,
                    child: Text(
                      subject.code ?? 'N/A',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: const Color(0xFF0EA5E9),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Subject Name
                  Expanded(
                    flex: 6,
                    child: Text(
                      subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // TA Name (for Doctor) or Doctor Name (for TA)
                  Expanded(
                    flex: 7,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        isTA ? subject.doctorName : getTAName(subject),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Department
                  Expanded(
                    flex: 5,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        subject.department ?? 'General',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5CF6),
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
    );
  }
}
