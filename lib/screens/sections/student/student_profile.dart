// lib/screens/sections/student/student_profile.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/student.dart';
import '../../../widgets/toast_message.dart';
import '../../../core/api_service.dart';

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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    ToastMessage.showError(context, 'Profile image upload coming soon!');
  }

  Future<void> _changePassword() async {
    // التحقق من تطابق كلمة المرور الجديدة
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ToastMessage.showError(context, 'New passwords do not match');
      return;
    }

    // التحقق من طول كلمة المرور
    if (_newPasswordController.text.length < 4) {
      ToastMessage.showError(context, 'Password must be at least 4 characters');
      return;
    }

    // التحقق من أن كلمة المرور الحالية غير فارغة
    if (_currentPasswordController.text.isEmpty) {
      ToastMessage.showError(context, 'Please enter current password');
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      final authState = context.read<AuthCubit>().state;
      final dataState = context.read<DataCubit>().state;
      final token = authState.token;

      // البحث عن الطالب للحصول على الـ student_id الصحيح
      Student? student;
      if (authState.user != null && dataState.students.isNotEmpty) {
        student = dataState.students.firstWhere(
          (s) =>
              s.id == authState.user!.id ||
              s.studentId == authState.user!.username,
          orElse: () => dataState.students.first,
        );
      }

      final studentId = student?.studentId ?? authState.user?.username ?? '';

      print('🔐 Attempting password change...');
      print('   Student ID: $studentId');
      print('   Token exists: ${token != null}');

      if (studentId.isEmpty || token == null) {
        if (!mounted) return;
        ToastMessage.showError(context, 'User not authenticated');
        return;
      }

      final response = await ApiService.changeStudentPassword(
          studentId, _newPasswordController.text, token);

      if (!mounted) return;
      print('📥 Response: $response');

      if (response['success'] == true) {
        if (mounted) {
          ToastMessage.showSuccess(context, 'Password changed successfully!');
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          setState(() {
            _showPasswordFields = false;
          });
        }
      } else {
        if (mounted) {
          ToastMessage.showError(
              context, response['error'] ?? 'Failed to change password');
        }
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Exception: $e');
      if (mounted) {
        ToastMessage.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _loadQRCode() async {
    setState(() {
      _isLoadingQR = true;
    });

    try {
      final authState = context.read<AuthCubit>().state;
      final studentId = authState.user?.id;
      final token = authState.token;

      if (studentId != null && token != null) {
        final response = await ApiService.getStudentQRCode(studentId, token);
        if (!mounted) return;
        if (response['success'] == true) {
          setState(() {
            _qrCodeData = response['qrCode']['encoded'];
          });
          print('✅ QR Code loaded for student ID: $studentId');
        } else {
          ToastMessage.showError(
              context, response['error'] ?? 'Failed to load QR Code');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ToastMessage.showError(context, 'Failed to load QR Code');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingQR = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final dataState = context.watch<DataCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;
    Student? student;

    if (user != null && dataState.students.isNotEmpty) {
      student = dataState.students.firstWhere(
        (s) => s.id == user.id || s.studentId == user.username,
        orElse: () => dataState.students.first,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).cardColor.withValues(alpha: 0.95),
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              student?.name.isNotEmpty == true
                                  ? student!.name[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Name
                    Text(
                      student?.name ?? user?.name ?? 'Student',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Info Section
                    _buildInfoSection(student, user),

                    const SizedBox(height: 32),

                    // Change Password Section
                    _buildChangePasswordSection(),

                    const SizedBox(height: 16),

                    // QR Code Section
                    _buildQRCodeSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(Student? student, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            _buildInfoCard(
              icon: Icons.badge,
              label: 'Student ID',
              value: student?.studentId ?? user?.username ?? 'N/A',
            ),
            _buildInfoCard(
              icon: Icons.person,
              label: 'Full Name',
              value: student?.name ?? user?.name ?? 'N/A',
            ),
            _buildInfoCard(
              icon: Icons.school,
              label: 'Level',
              value: 'Level ${student?.level ?? 1}',
            ),
            _buildInfoCard(
              icon: Icons.business,
              label: 'Department',
              value: student?.department ?? 'General',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
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

  Widget _buildChangePasswordSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: ExpansionTile(
        leading:
            Icon(Icons.lock_rounded, color: Theme.of(context).primaryColor),
        title: Text(
          'Change Password',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        trailing: Icon(
          _showPasswordFields
              ? Icons.keyboard_arrow_up
              : Icons.keyboard_arrow_down,
          color: isDark ? Colors.white : Colors.grey.shade600,
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _showPasswordFields = expanded;
          });
        },
        childrenPadding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: InputDecoration(
              labelText: 'Current Password',
              labelStyle: TextStyle(
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscureCurrent = !_obscureCurrent;
                  });
                },
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: InputDecoration(
              labelText: 'New Password',
              labelStyle: TextStyle(
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off : Icons.visibility,
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscureNew = !_obscureNew;
                  });
                },
              ),
              helperText: 'Minimum 4 characters',
              helperStyle: TextStyle(
                  color:
                      isDark ? const Color(0xFF64748B) : Colors.grey.shade500,
                  fontSize: 10),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              labelStyle: TextStyle(
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirm = !_obscureConfirm;
                  });
                },
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isChangingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isChangingPassword
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: ExpansionTile(
        leading: Icon(Icons.qr_code, color: Theme.of(context).primaryColor),
        title: Text(
          'My QR Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        trailing: Icon(
          _showQRCode ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: isDark ? Colors.white : Colors.grey.shade600,
        ),
        onExpansionChanged: (expanded) async {
          setState(() {
            _showQRCode = expanded;
          });
          if (expanded && _qrCodeData == null) {
            await _loadQRCode();
          }
        },
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (_isLoadingQR)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_qrCodeData != null && _qrCodeData!.isNotEmpty)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: _qrCodeData!,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan this QR code for attendance',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            )
          else
            Text(
              'No QR code available',
              style: TextStyle(
                  color:
                      isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}
