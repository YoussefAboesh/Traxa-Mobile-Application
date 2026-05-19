class AppConstants {
  static const String baseUrl = 'https://192.168.1.37:3443';

  static String get wsUrl {
    return baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  static const String loginEndpoint = '/api/login';
  static const String studentLoginEndpoint = '/api/student/login';
  static const String doctorLoginEndpoint = '/api/doctor/login';

  static const String studentsEndpoint = '/database/students.json';
  static const String doctorsEndpoint = '/database/doctors.json';
  static const String subjectsEndpoint = '/database/subjects.json';
  static const String lecturesEndpoint = '/database/lectures.json';
  static const String locationsEndpoint = '/database/locations.json';
  static const String timeslotsEndpoint = '/database/timeslots.json';

  static const String gradesEndpoint = '/api/grades/student';
  static const String attendanceEndpoint = '/api/attendance';
  static const String reportsEndpoint = '/api/attendance-reports';

  static const String tokenKey = 'auth_token';
  static const String userTypeKey = 'user_type';
  static const String userDataKey = 'user_data';
  static const String studentSessionKey = 'student_session';
  static const String doctorSessionKey = 'doctor_session';

  static const List<String> days = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday'
  ];
}
