// lib/widgets/theme_toggle_button.dart
// ✅ Widget مشترك — بدل تكرار الـ theme toggle في student و doctor
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/theme/theme_cubit.dart';

class ThemeToggleButton extends StatelessWidget {
  /// لون الـ gradient في light mode (اختياري)
  final Color? lightModeColor;

  const ThemeToggleButton({super.key, this.lightModeColor});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeCubit>().state.themeMode == ThemeMode.dark;
    final fallbackColor = lightModeColor ?? Colors.indigo.shade400;

    return GestureDetector(
      onTap: () => context.read<ThemeCubit>().toggleTheme(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: Container(
          key: ValueKey<bool>(isDarkMode),
          margin: const EdgeInsets.only(right: 8),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [Colors.amber.shade300, Colors.orange.shade400]
                  : [fallbackColor, fallbackColor.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isDarkMode ? Colors.amber : fallbackColor).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
