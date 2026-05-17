// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'services/websocket_service.dart';
import 'core/theme.dart';
import 'core/api_service.dart';
import 'core/constants.dart';
import 'cubit/auth/auth_cubit.dart';
import 'cubit/auth/auth_state.dart';
import 'cubit/data/data_cubit.dart';
import 'cubit/theme/theme_cubit.dart';
import 'screens/login_screen.dart';
import 'screens/doctor_screen.dart';
import 'screens/student_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  // The Traxa server runs on the local network with a self-signed
  // certificate, so its cert must be accepted. To avoid being exposed to
  // man-in-the-middle attacks elsewhere, we ONLY trust a self-signed cert
  // for the configured server host — every other host is still verified
  // normally.
  static final String _trustedHost = Uri.parse(AppConstants.baseUrl).host;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) =>
              host == _trustedHost;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.initToken();

  HttpOverrides.global = MyHttpOverrides();

  // Initialize WebSocket connection
  await WebSocketService.instance.connect();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => DataCubit()),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
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
              // Clamp the device's font-scale setting so an unusually large
              // system text size can't overflow/break layouts on any phone.
              // A manual TextScaler.linear clamp is used instead of
              // MediaQuery.withClampedTextScaling, which can assert-crash on
              // some devices' scalers.
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
            child: BlocConsumer<AuthCubit, AuthState>(
              listenWhen: (prev, curr) =>
                  curr.isAuthenticated &&
                  curr.user != null &&
                  (prev.user?.id != curr.user?.id || !prev.isAuthenticated),
              listener: (context, authState) {
                context.read<DataCubit>().fullReload();
              },
              builder: (context, authState) {
                // مفيش شاشة تحميل كاملة بعد كده — الشاشة بتفضل ثابتة
                // والـ Skeleton بيشتغل جوّاها أثناء تحميل/تحديث البيانات،
                // فالريفريش مايرجعش المستخدم لصفحة الـ Home.
                if (authState.isAuthenticated && authState.user != null) {
                  if (authState.user!.isDoctor ||
                      authState.user!.isTeachingAssistant) {
                    return const DoctorScreen();
                  } else {
                    return const StudentScreen();
                  }
                }
                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}