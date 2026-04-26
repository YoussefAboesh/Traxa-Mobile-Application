import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';

class StudentLectures extends StatefulWidget {
  const StudentLectures({super.key});

  @override
  State<StudentLectures> createState() => _StudentLecturesState();
}

class _StudentLecturesState extends State<StudentLectures> {
  String _semesterFilter = '';
  
  final List<String> _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'];
  
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
    
    List<dynamic> lectures = student != null 
        ? dataState.getLecturesForStudent(student)
        : <dynamic>[];
    
    // Apply semester filter
    if (_semesterFilter.isNotEmpty) {
      lectures = lectures.where((l) {
        final subject = dataState.subjects.firstWhere(
          (s) => s.id == l.subjectId,
          orElse: () => dataState.subjects.first,
        );
        return subject.semester.toString() == _semesterFilter;
      }).toList();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Text('Filter by Semester:'),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    value: _semesterFilter,
                    items: const ['', '1', '2'],
                    labels: const ['All Semesters', 'Semester 1', 'Semester 2'],
                    onChanged: (value) => setState(() => _semesterFilter = value ?? ''),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Lectures by Day
          ..._days.map((day) {
            final dayLectures = lectures.where((l) => l.day == day).toList();
            dayLectures.sort((a, b) => a.timeDisplay.compareTo(b.timeDisplay));
            
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    const Color(0xFF6366F1).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: const Border(
                  left: BorderSide(color: Color(0xFF8B5CF6), width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${dayLectures.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (dayLectures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No lectures',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    )
                  else
                    ...dayLectures.map((lecture) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildLectureCard(lecture),
                    )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildLectureCard(dynamic lecture) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lecture.subjectName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(lecture.timeDisplay, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              const SizedBox(width: 16),
              const Icon(Icons.location_on, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(lecture.locationName, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Level ${lecture.level} • ${lecture.department ?? 'N/A'}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          items: items.asMap().entries.map((entry) {
            return DropdownMenuItem(
              value: entry.value,
              child: Text(labels[entry.key]),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
