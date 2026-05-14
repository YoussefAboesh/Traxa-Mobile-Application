// lib/screens/sections/student/student_profile.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../widgets/toast_message.dart';
import '../../../core/api_service.dart';
import '../../../core/constants.dart';
import '../../../core/helpers.dart';

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

  // Profile Image (من السيرفر)
  String? _avatarUrl;
  bool _isLoadingAvatar = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Refresh
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
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
      await _loadAvatar();
    } catch (e) {
      print('Error refreshing profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ============================================
  // Avatar Methods (Server-side with Cache)
  // ============================================

  Future<void> _loadAvatar() async {
    final authState = context.read<AuthCubit>().state;
    if (authState.user == null) return;
    
    final studentId = authState.user!.username;
    final token = authState.token;
    
    if (token == null) return;
    
    setState(() => _isLoadingAvatar = true);
    
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/student/avatar/$studentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        setState(() {
          // ✅ إضافة timestamp عشان مايتكاشش، بس cached_network_image هيعتني بالـ cache
          _avatarUrl = '${AppConstants.baseUrl}/api/student/avatar/$studentId';
        });
      } else if (response.statusCode == 404) {
        setState(() => _avatarUrl = null);
      }
    } catch (e) {
      print('Error loading avatar: $e');
      setState(() => _avatarUrl = null);
    } finally {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  void _showImageOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),

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

              const SizedBox(height: 8),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
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
    
    final studentId = authState.user!.username;
    final token = authState.token!;
    
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      
      ToastMessage.showInfo(context, 'Uploading...');
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/api/student/avatar/$studentId'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('avatar', pickedFile.path));
      
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        
        if (data['success'] == true) {
          ToastMessage.showSuccess(context, 'Profile photo updated!');
          await _loadAvatar();
        } else {
          ToastMessage.showError(context, data['error'] ?? 'Upload failed');
        }
      } else {
        ToastMessage.showError(context, 'Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    }
  }

  Future<void> _removeAvatar() async {
    final authState = context.read<AuthCubit>().state;
    if (authState.user == null || authState.token == null) {
      ToastMessage.showError(context, 'Not authenticated');
      return;
    }
    
    final studentId = authState.user!.username;
    final token = authState.token!;
    
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/student/avatar/$studentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        ToastMessage.showSuccess(context, 'Photo removed');
        setState(() => _avatarUrl = null);
      } else {
        ToastMessage.showError(context, data['error'] ?? 'Failed to remove');
      }
    } catch (e) {
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

    return RefreshIndicator(
      onRefresh: _refreshProfile,
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // ===== Profile Card =====
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).cardColor.withValues(alpha: 0.95),
                        Theme.of(context).cardColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
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
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade300,
                              ),
                              child: _avatarUrl != null && !_isLoadingAvatar
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: _avatarUrl!,
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                        placeholder: (context, url) => Center(
                                          child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Text(
                                            (student?.name.isNotEmpty ?? false)
                                                ? student!.name[0].toUpperCase()
                                                : 'S',
                                            style: const TextStyle(
                                                fontSize: 40,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        (student?.name.isNotEmpty ?? false)
                                            ? student!.name[0].toUpperCase()
                                            : 'S',
                                        style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context).cardColor,
                                    width: 3),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(student?.name ?? user?.name ?? 'Student',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(student?.studentId ?? user?.username ?? '',
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).hintColor)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildInfoChip(
                              Icons.school, 'Level ${student?.level ?? '?'}'),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                              Icons.apartment, student?.department ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16)),
                          child: QrImageView(
                              data: _qrCodeData!,
                              version: QrVersions.auto,
                              size: 200),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _showQRCode = false;
                            _qrCodeData = null;
                          }),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Hide QR Code'),
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingQR ? null : _loadQRCode,
                            icon: _isLoadingQR
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.qr_code),
                            label: Text(
                                _isLoadingQR ? 'Loading...' : 'Show QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
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
                            const SizedBox(height: 12),
                            _buildPasswordField(
                                'New Password',
                                _newPasswordController,
                                _obscureNew,
                                (v) => setState(() => _obscureNew = v)),
                            const SizedBox(height: 12),
                            _buildPasswordField(
                                'Confirm Password',
                                _confirmPasswordController,
                                _obscureConfirm,
                                (v) => setState(() => _obscureConfirm = v)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(
                                        () => _showPasswordFields = false),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14))),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isChangingPassword
                                        ? null
                                        : _changePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    child: _isChangingPassword
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // Helper Widgets
  // ============================================

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).primaryColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
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
              Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: () => onToggle(!obscure),
        ),
      ),
    );
  }
}