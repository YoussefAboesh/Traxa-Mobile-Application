// lib/screens/sections/doctor/doctor_overview.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/helpers.dart';

class DoctorOverview extends StatefulWidget {
  const DoctorOverview({super.key});

  @override
  State<DoctorOverview> createState() => _DoctorOverviewState();
}

class _DoctorOverviewState extends State<DoctorOverview> {
  bool _isRefreshing = false;

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<DataCubit>().loadAllData();
    } catch (e) {
      print('Error refreshing doctor data: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;
    final doctorId = user?.effectiveDoctorId ?? 0;
    final isTA = user?.isTeachingAssistant == true;

    final doctorLectures =
        dataState.lectures.where((l) => l.doctorId == doctorId).toList();

    final todayName = getTodayDayName();
    final todaysLectures =
        doctorLectures.where((l) => l.day == todayName).toList();

    // Formatted date
    final now = DateTime.now();
    final dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final formattedDate =
        '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}, ${now.year}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            // ── Hero Header ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0C1A2E), const Color(0xFF0F2942)]
                        : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isTA 
                            ? 'Welcome back, Dr. ${user?.name ?? 'TA'} 🎓'
                            : 'Welcome back, ${user?.name ?? 'Doctor'} 👤',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  size: 7, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text('Active',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.layers_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Semester ${dataState.currentSemester}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Today's Schedule ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(FontAwesomeIcons.chalkboardUser, color: Color(0xFF0EA5E9), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today\'s Schedule',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              todayName,
                              style: const TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    if (todaysLectures.isEmpty)
                      _buildEmptySchedule()
                    else
                      ...todaysLectures.map((lecture) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: _buildLectureItem(lecture, context, isDark),
                          )),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Expanded spacer to fill empty space
            const SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySchedule() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_rounded,
                size: 48, color: Color(0xFF1E3A5F)),
            SizedBox(height: 12),
            Text(
              'No lectures or sections scheduled for today',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            SizedBox(height: 4),
            Text('Enjoy your day off! 🎉',
                style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildLectureItem(
      dynamic lecture, BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lecture.subjectName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(lecture.timeDisplay,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on_rounded,
                        size: 10, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(lecture.locationName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    'Level ${lecture.level} • ${lecture.department ?? 'General'}',
                    style: const TextStyle(
                        fontSize: 9, color: Color(0xFF64748B)),
                  ),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Text('Today',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0EA5E9))),
          ),
        ],
      ),
    );
  }
}