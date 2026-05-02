// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'core/theme.dart';
import 'core/api_service.dart';
import 'cubit/auth/auth_cubit.dart';
import 'cubit/auth/auth_state.dart';
import 'cubit/data/data_cubit.dart';
import 'cubit/data/data_state.dart';
import 'cubit/theme/theme_cubit.dart';
import 'screens/login_screen.dart';
import 'screens/doctor_screen.dart';
import 'screens/student_screen.dart';

// Override لتجاوز مشكلة الشهادة self-signed
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await ApiService.initToken();
  
  HttpOverrides.global = MyHttpOverrides();
  
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
          return MaterialApp(
            title: 'Traxa',
            debugShowCheckedModeBanner: false,
            themeMode: themeState.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, authState) {
                if (authState.isAuthenticated && authState.user != null) {
                  return BlocBuilder<DataCubit, DataState>(
                    builder: (context, dataState) {
                      if (dataState.loadingState.isLoading) {
                        return Scaffold(
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Loading your data...',
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (authState.user!.isDoctor) {
                        return const DoctorScreen();
                      } else {
                        return const StudentScreen();
                      }
                    },
                  );
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