import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle headlineLarge({Color? color}) => TextStyle(
        fontSize: 32.sp,
        fontWeight: FontWeight.bold,
        color: color,
      );

  static TextStyle headlineMedium({Color? color}) => TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.bold,
        color: color,
      );

  static TextStyle titleLarge({Color? color}) => TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle titleMedium({Color? color}) => TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle titleSmall({Color? color}) => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle bodyLarge({Color? color}) => TextStyle(
        fontSize: 16.sp,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontSize: 14.sp,
        color: color ?? AppColors.darkTextSecondary,
      );

  static TextStyle bodySmall({Color? color}) => TextStyle(
        fontSize: 12.sp,
        color: color ?? AppColors.darkTextHint,
      );

  static TextStyle appBar({required Color color}) => TextStyle(
        color: color,
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
      );
}
