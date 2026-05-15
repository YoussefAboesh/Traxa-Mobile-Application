// lib/screens/sections/doctor/doctor_profile.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../models/doctor.dart';
import '../../../models/teaching_assistant.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../widgets/toast_message.dart';

class DoctorProfile extends StatefulWidget {
  const DoctorProfile({super.key});

  @override
  State<DoctorProfile> createState() => _DoctorProfileState();
}

class _DoctorProfileState extends State<DoctorProfile> {
  String? _avatarUrl;
  bool _isLoadingAvatar = false;
  bool _isRefreshing = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<AuthCubit>().refreshUserData();
      await context.read<DataCubit>().loadAllData();
      await _loadAvatar();
    } catch (e) {
      print('Error refreshing profile: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadAvatar() async {
    final authState = context.read<AuthCubit>().state;
    if (authState.user == null) return;

    final doctorId = authState.user!.effectiveDoctorId.toString();
    final token = authState.token;

    if (token == null) return;

    setState(() => _isLoadingAvatar = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/doctor/avatar/$doctorId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _avatarUrl = '${AppConstants.baseUrl}/api/doctor/avatar/$doctorId';
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

    final doctorId = authState.user!.effectiveDoctorId.toString();
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
        Uri.parse('${AppConstants.baseUrl}/api/doctor/avatar/$doctorId'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files
          .add(await http.MultipartFile.fromPath('avatar', pickedFile.path));

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

    final doctorId = authState.user!.effectiveDoctorId.toString();
    final token = authState.token!;

    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/doctor/avatar/$doctorId'),
        headers: {'Authorization': 'Bearer $token'},
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
      body: RefreshIndicator(
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
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isTA
                            ? [const Color(0xFF059669), const Color(0xFF047857)]
                            : [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: (isTA ? const Color(0xFF059669) : const Color(0xFF0EA5E9))
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
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
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
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
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Center(
                                            child: Text(
                                              displayName!.isNotEmpty
                                                  ? displayName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 40,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0EA5E9),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          displayName!.isNotEmpty
                                              ? displayName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: isTA
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF0EA5E9),
                                          ),
                                        ),
                                      ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
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
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          displayName!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $displayId',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(roleIcon, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                role,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 7, color: Color(0xFF34D399)),
                              SizedBox(width: 4),
                              Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 11,
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

                  const SizedBox(height: 20),

                  // Username Card (Full Width)
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    title: 'USERNAME',
                    value: displayUsername,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 12),

                  // Email Card (Full Width)
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'EMAIL ADDRESS',
                    value: displayEmail ?? 'Not provided',
                    color: const Color(0xFF0EA5E9),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 12),

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
                      const SizedBox(width: 12),
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

                  const SizedBox(height: 12),

                  if (isTA && teachingAssistant?.supervisorDoctorId != null)
                    _buildInfoCard(
                      icon: Icons.verified_user,
                      title: 'SUPERVISOR DOCTOR ID',
                      value: '${teachingAssistant?.supervisorDoctorId}',
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),

                  const SizedBox(height: 80),
                ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
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
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
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
}