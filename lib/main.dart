import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants.dart';
import 'core/env/server_config.dart';
import 'core/di/app_providers.dart';
import 'core/di/service_locator.dart';
import 'core/theme.dart';
import 'cubit/auth/auth_cubit.dart';
import 'cubit/auth/auth_state.dart';
import 'cubit/data/data_cubit.dart';
import 'cubit/theme/theme_cubit.dart';
import 'features/auth/login_screen.dart';
import 'features/doctor/doctor_screen.dart';
import 'features/student/student_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Trust the host the user currently has configured — this changes
        // whenever they switch the server URL on the login screen.
        return host == Uri.parse(AppConstants.baseUrl).host;
      };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the user-configured server URL before any HTTP call goes out.
  await ServerConfig.load();
  HttpOverrides.global = MyHttpOverrides();

  // Single init point — registers all DI singletons and runs cubit bootstrap.
  await initServiceLocator();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return ScreenUtilInit(
            designSize: const Size(393, 873),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) => MaterialApp(
              title: 'Traxa',
              debugShowCheckedModeBanner: false,
              themeMode: themeState.themeMode,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              builder: (context, widget) {
                final mq = MediaQuery.of(context);
                final estimated = mq.textScaler.scale(100) / 100;
                final clamped = estimated.clamp(1.0, 1.2);
                return MediaQuery(
                  data: mq.copyWith(textScaler: TextScaler.linear(clamped)),
                  child: widget!,
                );
              },
              home: child,
            ),
            child: const _AuthGate(),
          );
        },
      ),
    );
  }
}

/// Pulled out so MaterialApp doesn't rebuild on every auth change.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          curr.isAuthenticated &&
          curr.user != null &&
          (prev.user?.id != curr.user?.id || !prev.isAuthenticated),
      listener: (context, authState) {
        context.read<DataCubit>().fullReload();
      },
      builder: (context, authState) {
        if (authState.isAuthenticated && authState.user != null) {
          if (authState.user!.isDoctor ||
              authState.user!.isTeachingAssistant) {
            return const DoctorScreen();
          }
          return const StudentScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
