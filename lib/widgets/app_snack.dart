import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppSnack {
  AppSnack._();

  static void success(BuildContext context, String message) =>
      _show(context, message, Colors.green, Icons.check_circle);

  static void error(BuildContext context, String message) =>
      _show(context, message, Colors.red, Icons.error_outline);

  static void warning(BuildContext context, String message) =>
      _show(context, message, Colors.orange, Icons.warning_amber);

  static void info(BuildContext context, String message) =>
      _show(context, message, const Color(0xFF0EA5E9), Icons.info_outline);

  static void custom(
    BuildContext context,
    String message, {
    required Color color,
    required IconData icon,
    Duration duration = const Duration(seconds: 2),
  }) =>
      _show(context, message, color, icon, duration: duration);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18.sp),
              SizedBox(width: 12.w),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
  }
}
