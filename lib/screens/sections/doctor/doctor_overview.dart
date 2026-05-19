import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/helpers.dart';
import '../../../core/theme.dart';
import '../../../widgets/app_skeleton.dart';
import '../../../core/logger.dart';

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
      logDebug('Error refreshing doctor data: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = context.isDarkMode;

    final user = authState.user;
    final doctorId = user?.effectiveDoctorId ?? 0;
    final isTA = user?.isTeachingAssistant == true;

    final doctorLectures =
        dataState.lectures.where((l) => l.doctorId == doctorId).toList();

    final todayName = getTodayDayName();
    final todaysLectures =
        doctorLectures.where((l) => l.day == todayName).toList();

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
      body: AppSkeleton(
        enabled: dataState.loadingState.isLoading,
        child: RefreshIndicator(
        onRefresh: _refreshData,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0C1A2E), const Color(0xFF0F2942)]
                        : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isTA
                            ? 'Welcome back, Dr. ${user?.name ?? 'TA'} 👩‍🏫'
                            : 'Welcome back, ${user?.name ?? 'Doctor'} 👤',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  size: 7.sp, color: const Color(0xFF10B981)),
                              SizedBox(width: 4.w),
                              Text('Active',
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      color: const Color(0xFF10B981),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.layers_rounded,
                                  size: 12.sp, color: Colors.white),
                              SizedBox(width: 4.w),
                              Text(
                                'Semester ${dataState.currentSemester}',
                                style: TextStyle(
                                    fontSize: 11.sp,
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

            SliverToBoxAdapter(child: SizedBox(height: 16.h)),

            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(FontAwesomeIcons.chalkboardUser, color: const Color(0xFF0EA5E9), size: 18.sp),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today\'s Schedule',
                                  style: TextStyle(
                                    color: const Color(0xFF0EA5E9),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                  color: const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              todayName,
                              style: TextStyle(
                                  color: const Color(0xFF0EA5E9),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    if (todaysLectures.isEmpty)
                      _buildEmptySchedule(isDark)
                    else
                      ...todaysLectures.map((lecture) => Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
                            child: _buildLectureItem(lecture, isDark),
                          )),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            ),

            const SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildEmptySchedule(bool isDark) {
    final textColor = isDark ? const Color(0xFF64748B) : Colors.grey.shade500;
    final iconColor = isDark ? const Color(0xFF334155) : Colors.grey.shade400;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 36.h),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_rounded,
                size: 48.sp, color: iconColor),
            SizedBox(height: 12.h),
            Text(
              'No lectures or sections scheduled for today',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 13.sp),
            ),
            SizedBox(height: 4.h),
            Text('Enjoy your day off! 🎉',
                style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildLectureItem(dynamic lecture, bool isDark) {
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
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
              width: 3.w,
              height: 44.h,
              decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(2.r))),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lecture.subjectName,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp)),
                  SizedBox(height: 3.h),
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 10, color: Color(0xFF94A3B8)),
                    SizedBox(width: 3.w),
                    Text(lecture.timeDisplay,
                        style: TextStyle(
                            fontSize: 10.sp, color: subTextColor)),
                    SizedBox(width: 10.w),
                    const Icon(Icons.location_on_rounded,
                        size: 10, color: Color(0xFF94A3B8)),
                    SizedBox(width: 3.w),
                    Flexible(
                      child: Text(lecture.locationName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.sp, color: subTextColor)),
                    ),
                  ]),
                  SizedBox(height: 2.h),
                  Text(
                    'Level ${lecture.level} • ${lecture.department ?? 'General'}',
                    style: TextStyle(
                        fontSize: 9.sp, color: subTextColor.withValues(alpha: 0.7)),
                  ),
                ]),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r)),
            child: Text('Today',
                style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0EA5E9))),
          ),
        ],
      ),
    );
  }
}
