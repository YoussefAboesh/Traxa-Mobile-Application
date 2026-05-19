import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState extends Equatable {
  final ThemeMode themeMode;

  const ThemeState({required this.themeMode});

  factory ThemeState.initial() => const ThemeState(themeMode: ThemeMode.system);

  @override
  List<Object?> get props => [themeMode];
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(ThemeState.initial()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('theme_mode');
    ThemeMode mode = ThemeMode.system;
    if (savedMode == 'dark') {
      mode = ThemeMode.dark;
    } else if (savedMode == 'light') {
      mode = ThemeMode.light;
    }
    emit(ThemeState(themeMode: mode));
  }

  Future<void> setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String savedMode = 'system';
    if (mode == ThemeMode.dark) {
      savedMode = 'dark';
    } else if (mode == ThemeMode.light) {
      savedMode = 'light';
    }
    await prefs.setString('theme_mode', savedMode);
    emit(ThemeState(themeMode: mode));
  }

  void toggleTheme() {
    final newMode = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : (state.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.dark);
    setTheme(newMode);
  }

  bool get isDarkMode {
    return state.themeMode == ThemeMode.dark;
  }
}
