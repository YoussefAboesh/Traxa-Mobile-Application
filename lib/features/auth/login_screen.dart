import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../cubit/auth/auth_cubit.dart';
import '../../cubit/auth/auth_state.dart';
import '../../cubit/data/data_cubit.dart';
import '../../core/utils/error_handler.dart';
import '../../core/logger.dart';
import '../../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _isStudentLogin = ValueNotifier<bool>(true);
  final _obscurePassword = ValueNotifier<bool>(true);
  final _isSubmitting = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _isStudentLogin.dispose();
    _obscurePassword.dispose();
    _isSubmitting.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _isSubmitting.value = true;

    final authCubit = context.read<AuthCubit>();
    await authCubit.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      isStudent: _isStudentLogin.value,
    );
    if (mounted) _isSubmitting.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: _onAuthStateChanged,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Logo(primaryColor: Theme.of(context).primaryColor),
                    SizedBox(height: 40.h),
                    _RoleToggle(selector: _isStudentLogin),
                    SizedBox(height: 40.h),
                    _LoginCard(
                      formKey: _formKey,
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      isStudentLogin: _isStudentLogin,
                      obscurePassword: _obscurePassword,
                      isSubmitting: _isSubmitting,
                      onSubmit: _handleLogin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onAuthStateChanged(BuildContext context, AuthState state) async {
    if (state.loadingState.hasError) {
      _isSubmitting.value = false;
      ErrorHandler.showErrorSnackBar(
        context,
        state.loadingState.errorMessage ?? 'Login failed',
      );
      return;
    }

    if (state.isAuthenticated && state.user != null) {
      final dataCubit = context.read<DataCubit>();
      final userName = state.user?.name ?? 'User';

      logDebug('✅ Login successful, loading fresh data...');
      await dataCubit.fullReload();

      if (!state.user!.isDoctor && state.token != null) {
        final studentId = state.user!.id;
        final token = state.token!;
        await dataCubit.loadStudentGradesWithToken(studentId, token);
        await dataCubit.checkGradesStatus(studentId, token);
      }

      if (context.mounted) {
        ErrorHandler.showSuccessSnackBar(context, 'Welcome $userName!');
      }
    }
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.primaryColor});
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 30.r,
              offset: Offset(0, 10.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: Image.asset(
            'icons/platform_logo.png',
            width: 290.w,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.selector});
  final ValueNotifier<bool> selector;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(50.r),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: selector,
        builder: (context, isStudent, _) => Row(
          children: [
            _ToggleButton(
              isActive: isStudent,
              label: 'Student',
              icon: Icons.school_rounded,
              onTap: () => selector.value = true,
            ),
            _ToggleButton(
              isActive: !isStudent,
              label: 'Doctor / TA',
              icon: FontAwesomeIcons.chalkboardUser,
              onTap: () => selector.value = false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.isActive,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool isActive;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(40.r),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16.sp,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                ),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                    color: isActive
                        ? Colors.white
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.isStudentLogin,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> isStudentLogin;
  final ValueNotifier<bool> obscurePassword;
  final ValueNotifier<bool> isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              // Title row — only rebuilds when role toggle flips.
              ValueListenableBuilder<bool>(
                valueListenable: isStudentLogin,
                builder: (context, isStudent, _) => _CardHeader(isStudent: isStudent),
              ),
              SizedBox(height: 24.h),

              // Username — needs role to pick icon/hint, isolated rebuild.
              ValueListenableBuilder<bool>(
                valueListenable: isStudentLogin,
                builder: (context, isStudent, _) => _UsernameField(
                  controller: usernameController,
                  isStudent: isStudent,
                ),
              ),
              SizedBox(height: 16.h),

              // Password — only the eye toggle is dynamic.
              ValueListenableBuilder<bool>(
                valueListenable: obscurePassword,
                builder: (context, obscure, _) => _PasswordField(
                  controller: passwordController,
                  obscure: obscure,
                  onToggle: () => obscurePassword.value = !obscure,
                ),
              ),
              SizedBox(height: 28.h),

              // Submit button — only the button rebuilds while loading.
              ValueListenableBuilder<bool>(
                valueListenable: isSubmitting,
                builder: (context, loading, _) => GradientButton(
                  label: 'Login',
                  isLoading: loading,
                  onPressed: loading ? null : onSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.isStudent});
  final bool isStudent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4.w,
              height: 28.h,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                isStudent ? 'Student Portal' : 'Doctor Portal',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          isStudent
              ? 'Access your academic dashboard'
              : 'Professional Dashboard for Doctors & TAs',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({required this.controller, required this.isStudent});
  final TextEditingController controller;
  final bool isStudent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15.sp),
      decoration: _fieldDecoration(
        context,
        prefixIcon: isStudent ? Icons.badge_rounded : Icons.person_rounded,
        hint: isStudent ? 'Student ID' : 'Username',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter ${isStudent ? "Student ID" : "username"}';
        }
        return null;
      },
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15.sp),
      decoration: _fieldDecoration(
        context,
        prefixIcon: Icons.lock_rounded,
        hint: 'Password',
        suffix: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: theme.hintColor,
            size: 20.sp,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter password';
        return null;
      },
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required IconData prefixIcon,
  required String hint,
  Widget? suffix,
}) {
  final theme = Theme.of(context);
  return InputDecoration(
    prefixIcon: Icon(prefixIcon, color: theme.primaryColor, size: 20.sp),
    suffixIcon: suffix,
    hintText: hint,
    hintStyle: TextStyle(color: theme.hintColor, fontSize: 14.sp),
    filled: true,
    fillColor: theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide(color: theme.primaryColor.withValues(alpha: 0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
  );
}
