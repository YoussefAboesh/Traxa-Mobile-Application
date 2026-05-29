import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/auth/auth_cubit.dart';
import '../../cubit/data/data_cubit.dart';
import '../../cubit/theme/theme_cubit.dart';
import 'service_locator.dart';

/// Bridges GetIt-owned cubits into the widget tree via `.value`, so
/// `context.read<X>()` still works in every screen without main.dart
/// re-creating cubits on every restart.
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: getIt<AuthCubit>()),
        BlocProvider<DataCubit>.value(value: getIt<DataCubit>()),
        BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
      ],
      child: child,
    );
  }
}
