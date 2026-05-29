// Backwards-compat facade. New code should import from the topic-specific
// files directly (api_endpoints / storage_keys / app_strings / env).
import 'env/app_env.dart';
import 'constants/api_endpoints.dart';
import 'constants/storage_keys.dart';
import 'constants/app_strings.dart';

export 'constants/api_endpoints.dart';
export 'constants/storage_keys.dart';
export 'constants/app_strings.dart';

@Deprecated('Use AppEnv.baseUrl / ApiEndpoints.* / StorageKeys.* / AppStrings.* instead')
class AppConstants {
  AppConstants._();

  static String get baseUrl => AppEnv.baseUrl;
  static String get wsUrl => AppEnv.wsUrl;

  static String get loginEndpoint => ApiEndpoints.login;
  static String get studentLoginEndpoint => ApiEndpoints.studentLogin;
  static String get doctorLoginEndpoint => ApiEndpoints.doctorLogin;

  static String get studentsEndpoint => ApiEndpoints.studentsDb;
  static String get doctorsEndpoint => ApiEndpoints.doctorsDb;
  static String get subjectsEndpoint => ApiEndpoints.subjectsDb;
  static String get lecturesEndpoint => ApiEndpoints.lecturesDb;
  static String get locationsEndpoint => ApiEndpoints.locationsDb;
  static String get timeslotsEndpoint => ApiEndpoints.timeslotsDb;
  static String get gradesEndpoint => ApiEndpoints.gradesByStudent;
  static String get attendanceEndpoint => ApiEndpoints.attendance;
  static String get reportsEndpoint => ApiEndpoints.attendanceReports;

  static String get tokenKey => StorageKeys.legacyAuthToken;
  static String get userTypeKey => StorageKeys.userType;
  static String get userDataKey => StorageKeys.userData;
  static String get studentSessionKey => StorageKeys.studentSession;
  static String get doctorSessionKey => StorageKeys.doctorSession;

  static List<String> get days => AppStrings.days;
}
