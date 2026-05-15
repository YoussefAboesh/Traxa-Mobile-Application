// lib/widgets/theme_toggle_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/theme/theme_cubit.dart';

class ThemeToggleButton extends StatelessWidget {
  final Color? lightModeColor;
  final double size;

  const ThemeToggleButton({
    super.key,
    this.lightModeColor,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeCubit>().state.themeMode == ThemeMode.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final fallbackColor = lightModeColor ?? primaryColor;

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
          width: size,
          height: size,
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
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}