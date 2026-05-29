import 'package:get_it/get_it.dart';
import '../api_service.dart';
import '../../services/token_holder.dart';
import '../../services/websocket_service.dart';
import '../../cubit/auth/auth_cubit.dart';
import '../../cubit/data/data_cubit.dart';
import '../../cubit/theme/theme_cubit.dart';
import '../../repositories/repositories.dart';

final GetIt getIt = GetIt.instance;

Future<void> initServiceLocator() async {
  await ApiService.initToken();
  if (!getIt.isRegistered<TokenHolder>()) {
    getIt.registerLazySingleton<TokenHolder>(() => TokenHolder());
  }
  await getIt<TokenHolder>().load();

  if (!getIt.isRegistered<WebSocketService>()) {
    getIt.registerLazySingleton<WebSocketService>(
      () => WebSocketService.instance,
    );
  }

  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(() => AuthRepository());
  }
  if (!getIt.isRegistered<StudentRepository>()) {
    getIt.registerLazySingleton<StudentRepository>(() => StudentRepository());
  }
  if (!getIt.isRegistered<DoctorRepository>()) {
    getIt.registerLazySingleton<DoctorRepository>(() => DoctorRepository());
  }
  if (!getIt.isRegistered<GradesRepository>()) {
    getIt.registerLazySingleton<GradesRepository>(() => GradesRepository());
  }
  if (!getIt.isRegistered<AttendanceRepository>()) {
    getIt.registerLazySingleton<AttendanceRepository>(
      () => AttendanceRepository(),
    );
  }
  if (!getIt.isRegistered<TaRepository>()) {
    getIt.registerLazySingleton<TaRepository>(() => TaRepository());
  }
  if (!getIt.isRegistered<SystemRepository>()) {
    getIt.registerLazySingleton<SystemRepository>(() => SystemRepository());
  }

  if (!getIt.isRegistered<AuthCubit>()) {
    getIt.registerLazySingleton<AuthCubit>(() => AuthCubit());
  }
  if (!getIt.isRegistered<DataCubit>()) {
    getIt.registerLazySingleton<DataCubit>(() => DataCubit());
  }
  if (!getIt.isRegistered<ThemeCubit>()) {
    getIt.registerLazySingleton<ThemeCubit>(() => ThemeCubit());
  }

  // Auth must restore the saved session before DataCubit fires its first
  // load — otherwise the API calls go out unauthenticated.
  await getIt<AuthCubit>().init();
  // ignore: discarded_futures
  getIt<DataCubit>().init();

  // ignore: discarded_futures
  getIt<WebSocketService>().connect();
}
