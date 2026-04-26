import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../models/subject.dart';

class StudentSubjects extends StatefulWidget {
  const StudentSubjects({super.key});

  @override
  State<StudentSubjects> createState() => _StudentSubjectsState();
}

class _StudentSubjectsState extends State<StudentSubjects> {
  String _semesterFilter = '';

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
    
    List<Subject> subjects = student != null 
        ? dataState.getSubjectsForStudent(student)
        : <Subject>[];
    
    // Apply semester filter
    if (_semesterFilter.isNotEmpty) {
      subjects = subjects.where((s) => s.semester.toString() == _semesterFilter).toList();
    }
    
    // Group by semester
    final semester1Subjects = subjects.where((s) => s.semester == 1).toList();
    final semester2Subjects = subjects.where((s) => s.semester == 2).toList();
    
    semester1Subjects.sort((a, b) => a.name.compareTo(b.name));
    semester2Subjects.sort((a, b) => a.name.compareTo(b.name));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          
          const SizedBox(height: 24),
          
          // Semester 1
          if (semester1Subjects.isNotEmpty && (_semesterFilter.isEmpty || _semesterFilter == '1'))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Semester 1',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    ),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    columns: const [
                      DataColumn(label: Text('Code')),
                      DataColumn(label: Text('Subject Name')),
                      DataColumn(label: Text('Doctor')),
                      DataColumn(label: Text('Credits'), numeric: true),
                    ],
                    rows: semester1Subjects.map((subject) {
                      return DataRow(cells: [
                        DataCell(Text(subject.code ?? 'N/A', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF8B5CF6)))),
                        DataCell(Text(subject.name)),
                        DataCell(Text(subject.doctorName)),
                        DataCell(Text('${subject.credits ?? 3}')),
                      ]);
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          
          // Semester 2
          if (semester2Subjects.isNotEmpty && (_semesterFilter.isEmpty || _semesterFilter == '2'))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Semester 2',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    ),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    columns: const [
                      DataColumn(label: Text('Code')),
                      DataColumn(label: Text('Subject Name')),
                      DataColumn(label: Text('Doctor')),
                      DataColumn(label: Text('Credits'), numeric: true),
                    ],
                    rows: semester2Subjects.map((subject) {
                      return DataRow(cells: [
                        DataCell(Text(subject.code ?? 'N/A', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF8B5CF6)))),
                        DataCell(Text(subject.name)),
                        DataCell(Text(subject.doctorName)),
                        DataCell(Text('${subject.credits ?? 3}')),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          
          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Center(
                child: Text(
                  'No subjects found',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                ),
              ),
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
