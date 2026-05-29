import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AcademicYearChip extends StatelessWidget {
  const AcademicYearChip({super.key, required this.year});

  final ValueNotifier<String> year;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: year,
      builder: (context, value, _) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 10.sp, color: Colors.purple),
            SizedBox(width: 4.w),
            Text(
              value,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
