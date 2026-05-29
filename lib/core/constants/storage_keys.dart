class StorageKeys {
  StorageKeys._();

  static const String userType = 'user_type';
  static const String userData = 'user_data';
  static const String studentSession = 'student_session';
  static const String doctorSession = 'doctor_session';
  static const String cachedAcademicYear = 'system_academic_year';
  static const String serverBaseUrl = 'server_base_url';

  static const String secureAuthToken = 'auth_token_secure';
  static const String secureUserData = 'user_data_secure';
  static const String secureRefreshToken = 'refresh_token_secure';

  // Kept only for migration off the unencrypted token.
  static const String legacyAuthToken = 'auth_token';
}
