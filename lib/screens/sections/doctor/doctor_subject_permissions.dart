// lib/screens/sections/doctor/doctor_subject_permissions.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../cubit/auth/auth_cubit.dart';
import '../../../cubit/data/data_cubit.dart';
import '../../../models/subject.dart';
import '../../../models/teaching_assistant.dart';
import '../../../core/api_service.dart';
import '../../../core/theme.dart';
import '../../../widgets/toast_message.dart';

class DoctorSubjectPermissions extends StatefulWidget {
  final Subject subject;
  final TeachingAssistant? currentTA;
  final List<TeachingAssistant> allTAs;

  const DoctorSubjectPermissions({
    super.key,
    required this.subject,
    this.currentTA,
    required this.allTAs,
  });

  @override
  State<DoctorSubjectPermissions> createState() =>
      _DoctorSubjectPermissionsState();
}

class _DoctorSubjectPermissionsState extends State<DoctorSubjectPermissions>
    with SingleTickerProviderStateMixin {
  TeachingAssistant? _selectedTA;
  bool _isSaving = false;
  bool _isLoading = false;

  // Permissions — default: everything allowed
  bool _canActivateSession = true;
  bool _canManageGrades = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selectedTA = widget.currentTA;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    if (_selectedTA != null) _loadPermissions();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────── API ───────────────────────

  Future<void> _loadPermissions() async {
    if (_selectedTA == null) return;
    final token = context.read<AuthCubit>().state.token;
    if (token == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTASubjectPermissions(
        _selectedTA!.id,
        widget.subject.id,
        token,
      );
      if (mounted) {
        setState(() {
          _canActivateSession = response['can_activate_session'] ?? true;
          _canManageGrades = response['can_manage_grades'] ?? true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedTA == null) {
      ToastMessage.showError(context, 'Please select a TA first');
      return;
    }
    final token = context.read<AuthCubit>().state.token;
    if (token == null) {
      ToastMessage.showError(context, 'Not authenticated');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ApiService.updateTASubjectPermissions(
        taId: _selectedTA!.id,
        subjectId: widget.subject.id,
        permissions: {
          'can_activate_session': _canActivateSession,
          'can_manage_grades': _canManageGrades,
        },
        token: token,
      );
      if (result['success'] == true) {
        ToastMessage.showSuccess(context, 'Permissions saved successfully');
        Navigator.pop(context, true);
      } else {
        ToastMessage.showError(
            context, result['error'] ?? 'Failed to save');
      }
    } catch (e) {
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _assignTA() async {
    if (_selectedTA == null) return;
    final token = context.read<AuthCubit>().state.token;
    if (token == null) {
      ToastMessage.showError(context, 'Not authenticated');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ApiService.assignTAToSubject(
        subjectId: widget.subject.id,
        taId: _selectedTA!.id,
        token: token,
      );
      if (result['success'] == true) {
        ToastMessage.showSuccess(context, 'TA assigned successfully');
        await context.read<DataCubit>().loadAllData();
        Navigator.pop(context, true);
      } else {
        ToastMessage.showError(
            context, result['error'] ?? 'Failed to assign TA');
      }
    } catch (e) {
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeTA() async {
    final confirm = await _showConfirmDialog(
      title: 'Remove TA',
      message:
          'Remove ${_selectedTA?.name} from ${widget.subject.name}?',
      confirmLabel: 'Remove',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    final token = context.read<AuthCubit>().state.token;
    if (token == null) {
      ToastMessage.showError(context, 'Not authenticated');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ApiService.removeTAFromSubject(
        subjectId: widget.subject.id,
        token: token,
      );
      if (result['success'] == true) {
        ToastMessage.showSuccess(context, 'TA removed successfully');
        await context.read<DataCubit>().loadAllData();
        Navigator.pop(context, true);
      } else {
        ToastMessage.showError(
            context, result['error'] ?? 'Failed to remove TA');
      }
    } catch (e) {
      ToastMessage.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    final isDark = context.isDarkMode;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B))),
        content: Text(message,
            style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── UI ───────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(isDark),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildSubjectCard(isDark),
                  const SizedBox(height: 16),
                  _buildTACard(isDark),
                  if (_selectedTA != null) ...[
                    const SizedBox(height: 16),
                    _buildPermissionsCard(isDark),
                    const SizedBox(height: 20),
                    _buildSaveButton(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16,
              color:
                  isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding:
            const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TA Permissions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              widget.subject.name,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(bool isDark) {
    final dept = widget.subject.department ?? 'General';
    final code = widget.subject.code ?? 'N/A';

    return _GlassCard(
      isDark: isDark,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subject.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Chip(label: code, color: const Color(0xFF8B5CF6)),
                    _Chip(
                        label: 'Level ${widget.subject.level}',
                        color: const Color(0xFF0EA5E9)),
                    _Chip(label: dept, color: const Color(0xFF10B981)),
                    _Chip(
                        label: 'Sem ${widget.subject.semester}',
                        color: Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTACard(bool isDark) {
    return _GlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded,
                    size: 18, color: Color(0xFF0EA5E9)),
              ),
              const SizedBox(width: 10),
              Text(
                'Assigned Teaching Assistant',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // TA Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TeachingAssistant?>(
                value: _selectedTA,
                isExpanded: true,
                dropdownColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8B5CF6)),
                style: TextStyle(
                  color:
                      isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 14,
                ),
                hint: Text(
                  'Select a Teaching Assistant',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF64748B)
                        : Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
                items: [
                  const DropdownMenuItem<TeachingAssistant?>(
                    value: null,
                    child: Text('No TA Assigned'),
                  ),
                  ...widget.allTAs.map((ta) => DropdownMenuItem(
                        value: ta,
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person,
                                  size: 16,
                                  color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 10),
                            Text(ta.name),
                          ],
                        ),
                      )),
                ],
                onChanged: _isSaving
                    ? null
                    : (ta) {
                        setState(() {
                          _selectedTA = ta;
                          _canActivateSession = true;
                          _canManageGrades = true;
                        });
                        if (ta != null) _loadPermissions();
                      },
              ),
            ),
          ),

          // Assign / Remove buttons
          if (_selectedTA != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Assign TA',
                    icon: Icons.link_rounded,
                    color: const Color(0xFF10B981),
                    onPressed: _isSaving ? null : _assignTA,
                    loading: _isSaving,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Remove TA',
                    icon: Icons.link_off_rounded,
                    color: Colors.red,
                    outlined: true,
                    onPressed: _isSaving ? null : _removeTA,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(bool isDark) {
    return _GlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded,
                    size: 18, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 10),
              Text(
                'TA Permissions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Info banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 11, color: Colors.amber),
                      children: const [
                        TextSpan(
                            text: 'By default everything is ',
                            style: TextStyle(
                                color: Colors.amber)),
                        TextSpan(
                            text: 'visible',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        TextSpan(text: '. Check to '),
                        TextSpan(
                            text: 'hide',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        TextSpan(text: ' from this TA.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            _PermissionTile(
              isDark: isDark,
              icon: Icons.play_circle_outline_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Hide Activate/End Session',
              subtitle:
                  'Hides the Activate Session button from My Sections for this subject',
              // tile shows "hide" — so value = !canActivate
              value: !_canActivateSession,
              onChanged: _isSaving
                  ? null
                  : (v) => setState(
                      () => _canActivateSession = !(v ?? false)),
            ),
            _buildDivider(isDark),
            _PermissionTile(
              isDark: isDark,
              icon: Icons.school_outlined,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Hide Grades Section',
              subtitle:
                  'Hides the grades section for this subject from this TA',
              value: !_canManageGrades,
              onChanged: _isSaving
                  ? null
                  : (v) =>
                      setState(() => _canManageGrades = !(v ?? false)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(
          color:
              isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
          height: 1,
        ),
      );

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePermissions,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Save Permissions',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────── Helper Widgets ───────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _GlassCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool loading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined ? color : Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          );

    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12));

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: shape,
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: shape,
      ),
      child: child,
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const _PermissionTile({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Custom checkbox styled like the website screenshot
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF8B5CF6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value
                      ? const Color(0xFF8B5CF6)
                      : (isDark
                          ? const Color(0xFF475569)
                          : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
