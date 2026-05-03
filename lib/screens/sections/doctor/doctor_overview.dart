// lib/screens/sections/doctor/doctor_overview.dart
// ✅ Fix: _getTodayDayName → getTodayDayName من helpers.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/helpers.dart';

class DoctorOverview extends StatelessWidget {
  const DoctorOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;
    final doctorId = user?.id ?? 0;

    final doctorSubjects = dataState.subjects.where((s) => s.doctorId == doctorId).toList();
    final doctorLectures = dataState.lectures.where((l) => l.doctorId == doctorId).toList();

    const activeSessions = 0;
    const todayAttendance = 0;

    // ✅ Fix: getTodayDayName من helpers.dart
    final todayName = getTodayDayName();
    final todaysLectures = doctorLectures.where((l) => l.day == todayName).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.school_rounded, color: Theme.of(context).primaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user?.name ?? 'Doctor', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Text('Doctor Portal', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0),
              delegate: SliverChildListDelegate([
                _buildBentoCard('My Subjects', doctorSubjects.length.toString(), Icons.book, [const Color(0xFF8B5CF6), const Color(0xFF6366F1)]),
                _buildBentoCard('Weekly Lectures', doctorLectures.length.toString(), Icons.school, [const Color(0xFF0EA5E9), const Color(0xFF0284C7)]),
                _buildBentoCard('Active Sessions', activeSessions.toString(), Icons.qr_code_scanner, [const Color(0xFF10B981), const Color(0xFF059669)]),
                _buildBentoCard("Today's Attendance", todayAttendance.toString(), Icons.people, [const Color(0xFFF59E0B), const Color(0xFFD97706)]),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text("Today's Schedule", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (todaysLectures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('No lectures scheduled for today', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                    )
                  else
                    ...todaysLectures.map((lecture) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: _buildLectureItem(lecture, context),
                    )),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.history, color: Color(0xFF10B981), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text('Recent Attendance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: Text('No attendance records', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildBentoCard(String title, String value, IconData icon, List<Color> colors) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors), borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 18)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
          ]),
        ],
      ),
    );
  }

  Widget _buildLectureItem(dynamic lecture, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(width: 3, height: 40, decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lecture.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.access_time, size: 10, color: Color(0xFF94A3B8)),
                const SizedBox(width: 2),
                Text(lecture.timeDisplay, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                const SizedBox(width: 10),
                const Icon(Icons.location_on, size: 10, color: Color(0xFF94A3B8)),
                const SizedBox(width: 2),
                Text(lecture.locationName, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(height: 2),
              Text('Level ${lecture.level} • ${lecture.department ?? 'General'}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Text('Today', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class BentoItem {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;
  BentoItem({required this.title, required this.value, required this.icon, required this.gradientColors});
}
