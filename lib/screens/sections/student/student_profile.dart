// lib/screens/sections/student/student_profile.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../widgets/toast_message.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/app_skeleton.dart';
import '../../../core/api_service.dart';
import '../../../core/constants.dart';
import '../../../core/helpers.dart';
import '../../../services/websocket_service.dart';

class StudentProfile extends StatefulWidget {
  const StudentProfile({super.key});

  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  // Change Password
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _showPasswordFields = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // QR Code
  bool _showQRCode = false;
  String? _qrCodeData;
  bool _isLoadingQR = false;

  // Profile Image (من السيرفر، مع كاش)
  final ImagePicker _imagePicker = ImagePicker();

  // Refresh
  bool _isRefreshing = false;

  /// رقم الطالب (student_id) — من الـ user أو من قائمة الطلاب كـ fallback.
  String? get _studentId {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return null;
    if (user.username.trim().isNotEmpty) return user.username.trim();
    // fallback لو الجلسة قديمة والـ username فاضي
    final students = context.read<DataCubit>().state.students;
    final s = findStudentSafely(
        userId: user.id, username: user.username, students: students);
    return s?.studentId;
  }

  /// نسخة الصورة — بتتغيّر مع كل فتح للصفحة/رفع/حذف، فالكاش بيتجدّد
  /// أوتوماتيك (cache-busting) من غير ما الصورة القديمة تفضل عالقة.
  int _avatarVersion = DateTime.now().millisecondsSinceEpoch;

  /// رابط صورة الطالب على السيرفر (مع نسخة عشان المزامنة مع الويب).
  String? get _avatarUrl {
    final id = _studentId;
    if (id == null || id.isEmpty) return null;
    return '${AppConstants.baseUrl}/api/student/avatar/$id?v=$_avatarVersion';
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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await context.read<DataCubit>().loadAllData();
      // مزامنة مع الويب: نجدّد نسخة الصورة فبتتجاب من السيرفر من جديد.
      _bumpAvatar();
    } catch (e) {
      print('Error refreshing profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
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

    final studentId = _studentId;
    if (studentId == null || studentId.isEmpty) {
      ToastMessage.showError(context, 'Student ID not found');
      return;
    }
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
        Uri.parse('${AppConstants.baseUrl}/api/student/avatar/$studentId'),
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
          // نجدّد النسخة عشان الصورة الجديدة تظهر فوراً.
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

    final studentId = _studentId;
    if (studentId == null || studentId.isEmpty) {
      ToastMessage.showError(context, 'Student ID not found');
      return;
    }
    final token = authState.token!;

    try {
      final url = _avatarUrl;
      // حذف مضمون: السيرفر بيمسح الملف فعلياً (حتى لو الصورة محطوطة من الويب).
      final ok = await ApiService.forceRemoveAvatar(
        kind: 'student',
        id: studentId,
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

  // ============================================
  // QR Code
  // ============================================

  Future<void> _loadQRCode() async {
    setState(() => _isLoadingQR = true);
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState.user == null || authState.token == null) {
        if (mounted) ToastMessage.showError(context, 'Not authenticated');
        return;
      }

      final response = await ApiService.getStudentQRCode(
        authState.user!.id,
        authState.token!,
      );

      if (!mounted) return;

      if (response['success'] == true && response['qrCode'] != null) {
        final qrCode = response['qrCode'];
        final qrData = qrCode['encoded'] ?? qrCode['raw'] ?? '';

        if (qrData.isNotEmpty) {
          setState(() {
            _qrCodeData = qrData;
            _showQRCode = true;
          });
        } else {
          ToastMessage.showError(context, 'QR code data is empty');
        }
      } else {
        final error = response['error'] ?? 'Failed to load QR code';
        ToastMessage.showError(context, error);
      }
    } catch (e) {
      if (!mounted) return;
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoadingQR = false);
    }
  }

  // ============================================
  // Change Password
  // ============================================

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword == currentPassword) {
      ToastMessage.showError(
        context,
        'Please choose a different password than your current one',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ToastMessage.showError(context, 'New passwords do not match');
      return;
    }

    if (newPassword.length < 4) {
      ToastMessage.showError(context, 'Password must be at least 4 characters');
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final authState = context.read<AuthCubit>().state;
      final dataState = context.read<DataCubit>().state;
      final token = authState.token;

      final student = (authState.user != null)
          ? findStudentSafely(
              userId: authState.user!.id,
              username: authState.user!.username,
              students: dataState.students,
            )
          : null;

      final studentId = student?.studentId ?? authState.user?.username ?? '';

      if (studentId.isEmpty || token == null) {
        if (!mounted) return;
        ToastMessage.showError(context, 'User not authenticated');
        return;
      }

      final isValidCurrent =
          await _verifyCurrentPassword(studentId, currentPassword);

      if (!isValidCurrent) {
        if (!mounted) return;
        ToastMessage.showError(context, 'Current password is incorrect');
        return;
      }

      final response = await ApiService.changeStudentPassword(
        studentId,
        newPassword,
        token,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ToastMessage.showSuccess(context, 'Password changed successfully!');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _showPasswordFields = false);
      } else {
        ToastMessage.showError(
            context, response['error'] ?? 'Failed to change password');
      }
    } catch (e) {
      if (!mounted) return;
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<bool> _verifyCurrentPassword(
      String studentId, String currentPassword) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${AppConstants.baseUrl}${AppConstants.studentLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': studentId,
          'password': currentPassword,
          'isFirstLogin': false,
        }),
      );

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      print('Error verifying password: $e');
      return false;
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;

    final student = (user != null)
        ? findStudentSafely(
            userId: user.id,
            username: user.username,
            students: dataState.students)
        : null;

    return AppSkeleton(
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
                // ===== Profile Card =====
                Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).cardColor.withValues(alpha: 0.95),
                        Theme.of(context).cardColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showImageOptions,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            ProfileAvatar(
                              url: _avatarUrl ?? '',
                              name: student?.name ?? user?.name ?? 'S',
                              size: 100.w,
                              backgroundColor: Colors.grey.shade300,
                              initialColor: Colors.white,
                            ),
                            Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context).cardColor,
                                    width: 3),
                              ),
                              child: Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14.sp),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(student?.name ?? user?.name ?? 'Student',
                          style: TextStyle(
                              fontSize: 22.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4.h),
                      Text(student?.studentId ?? user?.username ?? '',
                          style: TextStyle(
                              fontSize: 14.sp,
                              color: Theme.of(context).hintColor)),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildInfoChip(
                              Icons.school, 'Level ${student?.level ?? '?'}'),
                          SizedBox(width: 12.w),
                          _buildInfoChip(
                              Icons.apartment, student?.department ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // ===== QR Code Section =====
                _buildSectionCard(
                  icon: Icons.qr_code_2,
                  title: 'My QR Code',
                  child: Column(
                    children: [
                      if (_showQRCode &&
                          _qrCodeData != null &&
                          _qrCodeData!.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r)),
                          child: QrImageView(
                              data: _qrCodeData!,
                              version: QrVersions.auto,
                              size: 200.w),
                        ),
                        SizedBox(height: 12.h),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _showQRCode = false;
                            _qrCodeData = null;
                          }),
                          icon: Icon(Icons.close, size: 18.sp),
                          label: const Text('Hide QR Code'),
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingQR ? null : _loadQRCode,
                            icon: _isLoadingQR
                                ? SizedBox(
                                    width: 16.w,
                                    height: 16.w,
                                    child: const CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.qr_code),
                            label: Text(
                                _isLoadingQR ? 'Loading...' : 'Show QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // ===== Change Password Section =====
                _buildSectionCard(
                  icon: Icons.lock,
                  title: 'Change Password',
                  child: Column(
                    children: [
                      if (!_showPasswordFields)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showPasswordFields = true),
                            icon: const Icon(Icons.edit),
                            label: const Text('Change Password'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r)),
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.5)),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            _buildPasswordField(
                                'Current Password',
                                _currentPasswordController,
                                _obscureCurrent,
                                (v) => setState(() => _obscureCurrent = v)),
                            SizedBox(height: 12.h),
                            _buildPasswordField(
                                'New Password',
                                _newPasswordController,
                                _obscureNew,
                                (v) => setState(() => _obscureNew = v)),
                            SizedBox(height: 12.h),
                            _buildPasswordField(
                                'Confirm Password',
                                _confirmPasswordController,
                                _obscureConfirm,
                                (v) => setState(() => _obscureConfirm = v)),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(
                                        () => _showPasswordFields = false),
                                    style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 14.h),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14.r))),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isChangingPassword
                                        ? null
                                        : _changePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      padding: EdgeInsets.symmetric(
                                          vertical: 14.h),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14.r)),
                                    ),
                                    child: _isChangingPassword
                                        ? SizedBox(
                                            width: 20.w,
                                            height: 20.w,
                                            child: const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Text('Update'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // ===== Logout Button =====
                _buildLogoutButton(isDark),

                SizedBox(height: 80.h),
              ],
            ),
          ),
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

  // ============================================
  // Helper Widgets
  // ============================================

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: Theme.of(context).primaryColor),
          SizedBox(width: 6.w),
          Text(label,
              style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required IconData icon, required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 20.sp),
            SizedBox(width: 10.w),
            Text(title,
                style:
                    TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller,
      bool obscure, ValueChanged<bool> onToggle) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon:
              Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20.sp),
          onPressed: () => onToggle(!obscure),
        ),
      ),
    );
  }
}
