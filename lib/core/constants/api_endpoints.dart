class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/api/login';
  static const String studentLogin = '/api/student/login';
  static const String doctorLogin = '/api/doctor/login';
  static const String changeStudentPassword = '/api/student/change-password';

  // Static database files
  static const String studentsDb = '/database/students.json';
  static const String doctorsDb = '/database/doctors.json';
  static const String subjectsDb = '/database/subjects.json';
  static const String lecturesDb = '/database/lectures.json';
  static const String locationsDb = '/database/locations.json';
  static const String timeslotsDb = '/database/timeslots.json';

  // Public read-only
  static const String studentsPublic = '/api/students-public';
  static const String doctorsPublic = '/api/doctors-public';
  static const String subjectsPublic = '/api/subjects-public';
  static const String lecturesPublic = '/api/lectures-public';

  // Grades
  static const String gradesByStudent = '/api/grades/student';
  static String studentVisibleGrades(int id) => '$gradesByStudent/$id/visible';
  static String studentGradesDebug(int id) => '$gradesByStudent/$id/debug';
  static String gradeDistribution(int doctorId, int subjectId) =>
      '/api/grade-distributions/$doctorId/$subjectId';

  // Attendance
  static const String attendance = '/api/attendance';
  static const String attendanceReports = '/api/attendance-reports';
  static String attendanceReportById(Object id) =>
      '/api/attendance-reports/$id';
  static String attendanceReportsByDoctor(Object doctorId) =>
      '/api/attendance-reports/doctor/$doctorId';
  static String attendanceReportBySession(Object sessionId) =>
      '/api/attendance-reports/session/$sessionId';

  // Camera / host
  static const String cameraRequest = '/api/camera/request';

  // Attendance sessions (created by the camera page when it loads)
  static String attendanceSession(Object id) =>
      '/api/attendance-sessions/$id';

  // Active sessions
  static const String activeSessions = '/api/active-sessions';
  static String activeSession(Object id) => '/api/active-sessions/$id';
  static String activeSessionHeartbeat(Object id) =>
      '/api/active-sessions/$id/heartbeat';
  static String activeSessionBeginQr(Object id) =>
      '/api/active-sessions/$id/begin-qr-phase';
  static String attendanceSessionData(Object id) =>
      '/api/attendance-session-data/$id';

  // Subjects
  static const String subjects = '/api/subjects';
  static String subjectEnrolledStudents(int subjectId) =>
      '/api/subject/$subjectId/enrolled-students';

  // Sections
  static const String sections = '/api/sections';

  // TAs
  static const String teachingAssistantsList = '/api/teaching-assistants-list';
  static const String teachingAssistants = '/api/teaching-assistants';
  static String taPermissions(int taId) =>
      '/api/teaching-assistant/$taId/permissions';
  static String taSubjectPermissions(int taId, int subjectId) =>
      '/api/ta-subject-permissions/$taId/$subjectId';
  static String doctorTAs(int doctorId) =>
      '/api/doctor/$doctorId/teaching-assistants';

  // System
  static const String semesterMode = '/api/system/semester-mode';
  static const String academicSettings = '/api/academic/settings';

  // QR
  static String studentQrCode(int studentId) =>
      '/api/student/qrcode/$studentId';
  static String studentQrScan(int studentId) =>
      '/api/student/qrcode/scan/$studentId';
  static String doctorQrCodes(int doctorId) => '/api/doctor/qrcodes/$doctorId';

  // Enrollment
  static String enrollmentStatus(int studentId) =>
      '/api/enrollment/status/$studentId';
  static String enrollmentAvailable(int studentId, int semester) =>
      '/api/enrollment/available/$studentId/$semester';
  static const String enrollmentRegister = '/api/enrollment/register';
  static const String enrollmentDrop = '/api/enrollment/drop';

  // Avatar
  static String avatar(String kind, String id) => '/api/$kind/avatar/$id';

  // Subjects management
  static String assignSubjectTa(int subjectId) =>
      '/api/subjects/$subjectId/assign-ta';
}
