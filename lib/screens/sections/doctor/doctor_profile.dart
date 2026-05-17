// lib/screens/sections/doctor/doctor_profile.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../models/doctor.dart';
import '../../../models/teaching_assistant.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../core/api_service.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/toast_message.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/app_skeleton.dart';
import 'doctor_ta_management.dart';

class DoctorProfile extends StatefulWidget {
  const DoctorProfile({super.key});

  @override
  State<DoctorProfile> createState() => _DoctorProfileState();
}

class _DoctorProfileState extends State<DoctorProfile> {
  bool _isRefreshing = false;
  final ImagePicker _imagePicker = ImagePicker();

  /// نسخة الصورة — بتتغيّر مع كل رفع/حذف/تحديث (cache-busting).
  int _avatarVersion = DateTime.now().millisecondsSinceEpoch;

  /// رابط صورة الدكتور/المعيد على السيرفر (مع نسخة للمزامنة مع الويب).
  /// بنستخدم `user.id` (نفس الـ id للدكتور والمعيد) عشان مايحصلش تداخل.
  String? get _avatarUrl {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return null;
    return '${AppConstants.baseUrl}/api/doctor/avatar/${user.id}?v=$_avatarVersion';
  }

  /// يجدّد نسخة الصورة → CachedNetworkImage يجيب أحدث صورة من السيرفر.
  void _bumpAvatar() {
    if (mounted) {
      setState(() => _avatarVersion = DateTime.now().millisecondsSinceEpoch);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<AuthCubit>().refreshUserData();
      await context.read<DataCubit>().loadAllData();
      // مزامنة مع الويب: نجدّد نسخة الصورة فبتتجاب من السيرفر من جديد.
      _bumpAvatar();
    } catch (e) {
      print('Error refreshing profile: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showImageOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 16.h),
              _buildImageOptionTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo',
                color: const Color(0xFF0EA5E9),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              _buildImageOptionTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_avatarUrl != null)
                _buildImageOptionTile(
                  icon: Icons.delete_rounded,
                  label: 'Remove Photo',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAvatar();
                  },
                ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: color, size: 22.sp),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final authState = context.read<AuthCubit>().state;
    if (authState.user == null || authState.token == null) {
      ToastMessage.showError(context, 'Not authenticated');
      return;
    }

    final doctorId = authState.user!.id.toString();
    final token = authState.token!;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      ToastMessage.showInfo(context, 'Uploading...');

      // نوع الصورة لازم يتبعت صريح — من غيره السيرفر بيرفض الملف ويرجّع 500
      final lower = pickedFile.path.toLowerCase();
      String ext = 'jpg', subtype = 'jpeg';
      if (lower.endsWith('.png')) {
        ext = 'png';
        subtype = 'png';
      } else if (lower.endsWith('.gif')) {
        ext = 'gif';
        subtype = 'gif';
      } else if (lower.endsWith('.webp')) {
        ext = 'webp';
        subtype = 'webp';
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/api/doctor/avatar/$doctorId'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        pickedFile.path,
        filename: 'avatar.$ext',
        contentType: MediaType('image', subtype),
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);

        if (data['success'] == true) {
          final url = _avatarUrl;
          if (url != null) await ProfileAvatar.evict(url);
          _bumpAvatar();
          if (!mounted) return;
          ToastMessage.showSuccess(context, 'Profile photo updated!');
        } else {
          if (!mounted) return;
          ToastMessage.showError(context, data['error'] ?? 'Upload failed');
        }
      } else {
        String msg = 'Upload failed (${response.statusCode})';
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map && decoded['error'] != null) {
            msg = decoded['error'].toString();
          }
        } catch (_) {}
        if (!mounted) return;
        ToastMessage.showError(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _removeAvatar() async {
    final authState = context.read<AuthCubit>().state;
    if (authState.user == null || authState.token == null) {
      ToastMessage.showError(context, 'Not authenticated');
      return;
    }

    final doctorId = authState.user!.id.toString();
    final token = authState.token!;

    try {
      final url = _avatarUrl;
      // حذف مضمون: السيرفر بيمسح الملف فعلياً (حتى لو الصورة محطوطة من الويب).
      final ok = await ApiService.forceRemoveAvatar(
        kind: 'doctor',
        id: doctorId,
        token: token,
      );
      if (url != null) await ProfileAvatar.evict(url);
      _bumpAvatar();
      if (!mounted) return;
      if (ok) {
        ToastMessage.showSuccess(context, 'Photo removed');
      } else {
        ToastMessage.showError(context, 'Failed to remove photo');
      }
    } catch (e) {
      if (!mounted) return;
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = context.isDarkMode;
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    final isTA = user.isTeachingAssistant;
    final doctorId = user.effectiveDoctorId;

    // Get doctor/TA details from dataState
    Doctor? doctor;
    TeachingAssistant? teachingAssistant;

    if (isTA) {
      teachingAssistant = dataState.teachingAssistants.firstWhere(
        (ta) => ta.id == user.id,
        orElse: () => TeachingAssistant(
          id: user.id,
          name: user.name,
          username: user.username,
          email: user.email,
        ),
      );
    } else {
      doctor = dataState.doctors.firstWhere(
        (d) => d.id == doctorId,
        orElse: () => Doctor(
          id: doctorId,
          name: user.name,
          username: user.username,
          email: user.email,
        ),
      );
    }

    final displayId = isTA
        ? (teachingAssistant?.id.toString() ?? user.username)
        : (doctor?.id.toString() ?? user.username);
    final displayName = isTA ? teachingAssistant?.name : doctor?.name ?? user.name;
    final displayUsername = user.username;
    final displayEmail = isTA ? teachingAssistant?.email : doctor?.email ?? user.email;
    final role = isTA ? 'Teaching Assistant' : 'Professor / Doctor';
    final roleIcon = isTA ? Icons.school_rounded : Icons.work_rounded;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSkeleton(
        enabled: dataState.loadingState.isLoading,
        child: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20.r),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 600.w),
              child: Column(
                children: [
                  // Profile Card
                  Container(
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isTA
                            ? [const Color(0xFF059669), const Color(0xFF047857)]
                            : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: (isTA ? const Color(0xFF059669) : const Color(0xFF0EA5E9))
                              .withValues(alpha: 0.3),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar with edit button
                        GestureDetector(
                          onTap: _showImageOptions,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 100.w,
                                height: 100.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10.r,
                                      offset: Offset(0, 4.h),
                                    ),
                                  ],
                                ),
                                child: ProfileAvatar(
                                  url: _avatarUrl ?? '',
                                  name: displayName ?? '?',
                                  size: 100.w,
                                  backgroundColor: Colors.white,
                                  initialColor: isTA
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF0EA5E9),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isTA
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF0EA5E9),
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: isTA
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF0EA5E9),
                                  size: 14.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          displayName!,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'ID: $displayId',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(roleIcon, size: 14.sp, color: Colors.white),
                              SizedBox(width: 6.w),
                              Text(
                                role,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 7.sp, color: const Color(0xFF34D399)),
                              SizedBox(width: 4.w),
                              Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Username Card (Full Width)
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    title: 'USERNAME',
                    value: displayUsername,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),

                  SizedBox(height: 12.h),

                  // Email Card (Full Width)
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'EMAIL ADDRESS',
                    value: displayEmail ?? 'Not provided',
                    color: const Color(0xFF0EA5E9),
                    isDark: isDark,
                  ),

                  SizedBox(height: 12.h),

                  // ID Number and Member Since in Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.badge_outlined,
                          title: 'ID NUMBER',
                          value: displayId,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.calendar_today,
                          title: 'MEMBER SINCE',
                          value: '2026',
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),

                  if (isTA && teachingAssistant?.supervisorDoctorId != null)
                    _buildInfoCard(
                      icon: Icons.verified_user,
                      title: 'SUPERVISOR DOCTOR ID',
                      value: '${teachingAssistant?.supervisorDoctorId}',
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),

                  SizedBox(height: 20.h),

                  // TA Management (Doctors only)
                  if (!isTA) ...[
                    _buildActionTile(
                      icon: Icons.shield_outlined,
                      label: 'TA Management',
                      color: const Color(0xFF0EA5E9),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DoctorTAManagement(),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Logout button
                  _buildLogoutButton(isDark),

                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 16.sp, color: color),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 18.sp, color: color),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20.sp,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(isDark),
        icon: Icon(Icons.logout_rounded, size: 20.sp),
        label: Text(
          'Logout',
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent, size: 28.sp),
            SizedBox(width: 12.w),
            Text(
              'Logout',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().logout();
              context.read<DataCubit>().clearData();
              WebSocketService.instance.disconnect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
