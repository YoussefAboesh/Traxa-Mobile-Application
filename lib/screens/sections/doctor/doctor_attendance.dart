// lib/screens/sections/doctor/doctor_attendance.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/lecture.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';

class DoctorAttendance extends StatefulWidget {
  const DoctorAttendance({super.key});

  @override
  State<DoctorAttendance> createState() => _DoctorAttendanceState();
}

class _DoctorAttendanceState extends State<DoctorAttendance> {
  String _selectedDay = '';
  bool _showActiveSessions = false;
  int _selectedSemester = 0;
  int _selectedLevel = 0;

  Lecture? _activeSession;
  List<Student>? _sessionStudents;
  bool _showStudentList = false;

  final List<String> _days = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday'
  ];
  final List<int> _levels = [1, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;
    final doctorId = user?.id ?? 0;

    List<Subject> doctorSubjects =
        dataState.subjects.where((s) => s.doctorId == doctorId).toList();

    final doctorSubjectIds = doctorSubjects.map((s) => s.id).toList();

    List<Lecture> doctorLectures = dataState.lectures
        .where((l) => doctorSubjectIds.contains(l.subjectId))
        .toList();

    if (_selectedLevel != 0) {
      doctorLectures =
          doctorLectures.where((l) => l.level == _selectedLevel).toList();
    }

    if (_selectedSemester == 1) {
      final semester1SubjectIds = doctorSubjects
          .where((s) => s.semester == 1)
          .map((s) => s.id)
          .toList();
      doctorLectures = doctorLectures
          .where((l) => semester1SubjectIds.contains(l.subjectId))
          .toList();
    } else if (_selectedSemester == 2) {
      final semester2SubjectIds = doctorSubjects
          .where((s) => s.semester == 2)
          .map((s) => s.id)
          .toList();
      doctorLectures = doctorLectures
          .where((l) => semester2SubjectIds.contains(l.subjectId))
          .toList();
    }

    if (_selectedDay.isNotEmpty) {
      doctorLectures =
          doctorLectures.where((l) => l.day == _selectedDay).toList();
    }

    final Map<String, List<Lecture>> lecturesByDay = {};
    final daysToShow = _selectedDay.isNotEmpty ? [_selectedDay] : _days;
    for (final day in daysToShow) {
      lecturesByDay[day] = doctorLectures.where((l) => l.day == day).toList();
      lecturesByDay[day]!
          .sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
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
                    onTap: () => setState(() {
                      _showActiveSessions = false;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_showActiveSessions
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
                            color: !_showActiveSessions
                                ? Colors.white
                                : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Scheduled Lectures',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: !_showActiveSessions
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showActiveSessions = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _showActiveSessions
                            ? Theme.of(context).primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 16,
                            color: _showActiveSessions
                                ? Colors.white
                                : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live Sessions',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _showActiveSessions
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey.shade600),
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
          Expanded(
            child: _showActiveSessions
                ? _buildActiveSessionsContent()
                : _buildLecturesContent(lecturesByDay),
          ),
        ],
      ),
    );
  }

  Widget _buildLecturesContent(Map<String, List<Lecture>> lecturesByDay) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
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
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
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
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 12,
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
                      onChanged: (value) =>
                          setState(() => _selectedLevel = value ?? 0),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
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
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 12,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 0, child: Text('All Semesters')),
                        DropdownMenuItem(value: 1, child: Text('Semester 1')),
                        DropdownMenuItem(value: 2, child: Text('Semester 2')),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedSemester = value ?? 0),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDay.isEmpty ? null : _selectedDay,
                      isExpanded: true,
                      hint: Text(
                        'All Days',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 12,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600,
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All Days')),
                        ..._days.map((day) =>
                            DropdownMenuItem(value: day, child: Text(day))),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedDay = value ?? ''),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, dayIndex) {
              final day = daysToShow[dayIndex];
              final dayLectures = lecturesByDay[day] ?? [];

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                      const Color(0xFF0284C7).withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    left: BorderSide(
                        color: Theme.of(context).primaryColor, width: 3),
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${dayLectures.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF0EA5E9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...dayLectures.map((lecture) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: _buildLectureCard(lecture),
                        )),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
            childCount: daysToShow.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  List<String> get daysToShow {
    return _selectedDay.isNotEmpty ? [_selectedDay] : _days;
  }

  Widget _buildLectureCard(Lecture lecture) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _activeSession?.id == lecture.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: Colors.green, width: 1) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Theme.of(context).primaryColor,
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 2),
                    Text(
                      lecture.timeDisplay,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on,
                        size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 2),
                    Text(
                      lecture.locationName,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Level ${lecture.level} • ${lecture.department ?? 'General'}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            ElevatedButton(
              onPressed: () {
                _showEndSessionConfirmDialog(lecture);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'End',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            )
          else
            ElevatedButton(
              onPressed: _activeSession != null
                  ? null
                  : () {
                      _showActivateConfirmDialog(lecture);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _activeSession != null ? Colors.grey : Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _activeSession != null ? 'Active' : 'Activate',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dataState = context.read<DataCubit>().state;

    if (_activeSession == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No active sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activate a lecture to start attendance',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // جلب طلاب المادة من الداتابيز
    if (_sessionStudents == null) {
      final allStudents = dataState.students;

      _sessionStudents = allStudents
          .where((s) =>
              s.level == _activeSession!.level &&
              s.department == _activeSession!.department)
          .toList();
    }

    final totalStudents = _sessionStudents?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  const Color(0xFF0284C7).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeSession!.subjectName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      _activeSession!.timeDisplay,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      _activeSession!.locationName,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${_activeSession!.level} • ${_activeSession!.department ?? 'General'}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            totalStudents.toString(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            '0',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Confirmed',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            '0',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Pending',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // View Students Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _showStudentList = !_showStudentList;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                side: const BorderSide(color: Color(0xFF0EA5E9)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showStudentList ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_showStudentList
                      ? 'Hide Students'
                      : 'View Students ($totalStudents)'),
                ],
              ),
            ),
          ),

          // Students List (تظهر فقط عند الضغط على View Students)
          if (_showStudentList &&
              _sessionStudents != null &&
              _sessionStudents!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('STUDENT ID',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0EA5E9))),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('NAME',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0EA5E9))),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text('STATUS',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0EA5E9)),
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ),
                  ..._sessionStudents!.map((student) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(student.studentId,
                                  style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: const Color(0xFF0EA5E9))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(student.name,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B))),
                            ),
                            SizedBox(
                              width: 70,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Absent',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showEndSessionConfirmDialog(_activeSession!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'End Session',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActivateConfirmDialog(Lecture lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.play_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Activate Session',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to activate "${lecture.subjectName}" attendance session?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _activeSession = lecture;
                _showActiveSessions = true;
                _sessionStudents = null;
                _showStudentList = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session activated: ${lecture.subjectName}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  void _showEndSessionConfirmDialog(Lecture lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.stop_circle, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('End Session', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to end "${lecture.subjectName}" attendance session?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              setState(() {
                _activeSession = null;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session ended.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}
