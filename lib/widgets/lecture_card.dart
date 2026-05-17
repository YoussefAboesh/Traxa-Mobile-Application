import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/lecture.dart';

class LectureCard extends StatelessWidget {
  final Lecture lecture;
  final bool showAction;
  final VoidCallback? onActivate;
  final VoidCallback? onEnd;

  const LectureCard({
    super.key,
    required this.lecture,
    this.showAction = false,
    this.onActivate,
    this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lecture.subjectName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12.sp, color: const Color(0xFF94A3B8)),
                    SizedBox(width: 4.w),
                    Text(
                      lecture.timeDisplay,
                      style: TextStyle(fontSize: 11.sp, color: const Color(0xFF94A3B8)),
                    ),
                    SizedBox(width: 12.w),
                    Icon(Icons.location_on, size: 12.sp, color: const Color(0xFF94A3B8)),
                    SizedBox(width: 4.w),
                    Text(
                      lecture.locationName,
                      style: TextStyle(fontSize: 11.sp, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  'Level ${lecture.level} • ${lecture.department ?? 'N/A'}',
                  style: TextStyle(fontSize: 10.sp, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          if (showAction)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Activate',
                style: TextStyle(fontSize: 10.sp, color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}
