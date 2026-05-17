// lib/widgets/app_skeleton.dart
//
// نظام التحميل الحديث (Skeleton) المستخدم في كل التطبيق بدلاً من شكل
// الدائرة التقليدي (CircularProgressIndicator).
//
// • AppSkeleton: غلاف بسيط بيحوّل أي محتوى لـ skeleton لما enabled = true.
// • SkeletonCardList: قائمة كروت وهمية تُعرض في أماكن التحميل الكامل
//   (لما مفيش بيانات حقيقية نعملها skeleton).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// غلاف موحّد للـ Skeletonizer — بيخلي كل الشاشات تستخدم نفس التأثير.
class AppSkeleton extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const AppSkeleton({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Skeletonizer(
      enabled: enabled,
      enableSwitchAnimation: true,
      effect: ShimmerEffect(
        baseColor: isDark
            ? const Color(0xFF1E293B)
            : Colors.grey.shade300,
        highlightColor: isDark
            ? const Color(0xFF334155)
            : Colors.grey.shade100,
        duration: const Duration(milliseconds: 1100),
      ),
      child: child,
    );
  }
}

/// قائمة كروت وهمية (placeholder) — تُستخدم كبديل لشاشة التحميل الكاملة.
class SkeletonCardList extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  /// لما يكون جوّه Column/Sliver محتاج shrinkWrap.
  final bool shrinkWrap;

  const SkeletonCardList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      enabled: true,
      child: ListView.separated(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (_, __) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14.h,
                  width: double.infinity,
                  color: Colors.grey,
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 11.h,
                  width: 160.w,
                  color: Colors.grey,
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 11.h,
                  width: 100.w,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
