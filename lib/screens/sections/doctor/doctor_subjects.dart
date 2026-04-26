// lib/screens/sections/doctor/doctor_subjects.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/subject.dart';

class DoctorSubjects extends StatefulWidget {
  const DoctorSubjects({super.key});

  @override
  State<DoctorSubjects> createState() => _DoctorSubjectsState();
}

class _DoctorSubjectsState extends State<DoctorSubjects> {
  String _searchQuery = '';
  int _selectedSemester = 0; // 0 = All, 1 = Semester 1, 2 = Semester 2
  int _selectedLevel = 0; // 0 = All Levels
  bool _showFilters = true;

  final List<int> _levels = [1, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;
    final doctorId = user?.id ?? 0;

    // جلب المواد الخاصة بالدكتور
    List<Subject> doctorSubjects = dataState.subjects
        .where((s) => s.doctorId == doctorId)
        .toList();

    // فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      doctorSubjects = doctorSubjects.where((s) =>
        s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (s.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    // فلترة حسب المستوى
    if (_selectedLevel != 0) {
      doctorSubjects = doctorSubjects.where((s) => s.level == _selectedLevel).toList();
    }

    // فلترة حسب السيمستر
    if (_selectedSemester == 1) {
      doctorSubjects = doctorSubjects.where((s) => s.semester == 1).toList();
    } else if (_selectedSemester == 2) {
      doctorSubjects = doctorSubjects.where((s) => s.semester == 2).toList();
    }

    // تجميع المواد حسب المستوى
    final Map<int, List<Subject>> subjectsByLevel = {};
    for (final level in _levels) {
      final levelSubjects = doctorSubjects.where((s) => s.level == level).toList();
      if (levelSubjects.isNotEmpty) {
        subjectsByLevel[level] = levelSubjects;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            title: const Text('My Subjects'),
            centerTitle: false,
            floating: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),

          // Search and Filters
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search subjects...',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                        size: 18,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                size: 18,
                              ),
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
                  
                  const SizedBox(height: 12),
                  
                  // Filter Row
                  Row(
                    children: [
                      // Filter button
                      GestureDetector(
                        onTap: () => setState(() => _showFilters = !_showFilters),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _showFilters
                                ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _showFilters
                                  ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                                size: 16,
                                color: _showFilters
                                    ? Theme.of(context).primaryColor
                                    : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _showFilters
                                      ? Theme.of(context).primaryColor
                                      : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                                ),
                              ),
                            ],
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
                                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                              ),
                              items: [
                                const DropdownMenuItem(value: 0, child: Text('All Levels')),
                                ..._levels.map((level) => DropdownMenuItem(
                                  value: level,
                                  child: Text('Level $level'),
                                )),
                              ],
                              onChanged: (value) => setState(() => _selectedLevel = value ?? 0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_showFilters) ...[
                    const SizedBox(height: 12),
                    // Semester Filter
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
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('All Semesters')),
                            DropdownMenuItem(value: 1, child: Text('Semester 1')),
                            DropdownMenuItem(value: 2, child: Text('Semester 2')),
                          ],
                          onChanged: (value) => setState(() => _selectedSemester = value ?? 0),
                        ),
                      ),
                    ),
                  ],
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
                  
                  // تجميع المواد حسب السيمستر داخل المستوى
                  final semester1Subjects = levelSubjects.where((s) => s.semester == 1).toList();
                  final semester2Subjects = levelSubjects.where((s) => s.semester == 2).toList();
                  
                  semester1Subjects.sort((a, b) => a.name.compareTo(b.name));
                  semester2Subjects.sort((a, b) => a.name.compareTo(b.name));
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Level $level',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${levelSubjects.length} subjects',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Semester 1
                        if (semester1Subjects.isNotEmpty && (_selectedSemester == 0 || _selectedSemester == 1))
                          _buildSemesterSection('Semester 1', semester1Subjects),
                        
                        // Semester 2
                        if (semester2Subjects.isNotEmpty && (_selectedSemester == 0 || _selectedSemester == 2))
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildSemesterSection('Semester 2', semester2Subjects),
                          ),
                        
                        const SizedBox(height: 8),
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
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'No subjects found',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildSemesterSection(String title, List<Subject> subjects) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0EA5E9),
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        // Table
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'CODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'SUBJECT NAME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'DEPARTMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          subject.code ?? 'N/A',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: const Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          subject.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subject.department ?? 'General',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF10B981),
                            ),
                            textAlign: TextAlign.center,
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
      ],
    );
  }
}