// lib/core/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiService {
  static String? _token;
  static bool _isInitialized = false;

  // ================= TOKEN MANAGEMENT =================

  // تهيئة التوكن من SharedPreferences عند بدء التشغيل
  static Future<void> initToken() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(AppConstants.tokenKey);

      if (_token != null) {
        print(
            '🔑 Token loaded from SharedPreferences: ${_token!.substring(0, 20)}...');
      } else {
        print('🔑 No token found in SharedPreferences');
      }

      _isInitialized = true;
    } catch (e) {
      print('❌ Error loading token: $e');
      _isInitialized = true;
    }
  }

  // حفظ التوكن في SharedPreferences
  static Future<void> setToken(String? token) async {
    _token = token;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (token != null && token.isNotEmpty) {
        await prefs.setString(AppConstants.tokenKey, token);
        print(
            '🔑 Token saved to SharedPreferences: ${token.substring(0, 20)}...');
      } else {
        await prefs.remove(AppConstants.tokenKey);
        print('🔑 Token removed from SharedPreferences');
      }
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  // حذف التوكن (عند تسجيل الخروج)
  static Future<void> clearToken() async {
    _token = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.tokenKey);
      print('🔑 Token cleared from SharedPreferences');
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

  // الحصول على التوكن الحالي
  static String? getToken() {
    return _token;
  }

  // التحقق من وجود توكن صالح
  static bool get hasValidToken {
    return _token != null && _token!.isNotEmpty;
  }

  // headers موحدة لكل requests
  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
      print('🔐 Token attached to request (length: ${_token!.length})');
    } else {
      print('⚠️ No token available for request');
    }

    return headers;
  }

  // ================= LOGIN =================

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      print('🔐 Login attempt for: $username');

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.loginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);
      print('📡 Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        await setToken(data['token']);
        print('✅ Login successful, token saved');
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        print('❌ Login failed: ${data['error']}');
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> studentLogin(
      String studentId, String password, bool isFirstLogin) async {
    try {
      print('🔐 Student login attempt: $studentId');

      final response = await http.post(
        Uri.parse(
            '${AppConstants.baseUrl}${AppConstants.studentLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': studentId,
          'password': password,
          'isFirstLogin': isFirstLogin,
        }),
      );

      final data = jsonDecode(response.body);
      print('📡 Student login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        await setToken(data['token']);
        print('✅ Student login successful, token saved');
        return {
          'success': true,
          'token': data['token'],
          'student': data['student'],
        };
      } else {
        print('❌ Student login failed: ${data['error']}');
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      print('❌ Student login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> doctorLogin(
      String username, String password) async {
    try {
      print('🔐 Doctor login attempt: $username');

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.doctorLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);
      print('📡 Doctor login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        await setToken(data['token']);
        print('✅ Doctor login successful, token saved');
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        print('❌ Doctor login failed: ${data['error']}');
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      print('❌ Doctor login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // تسجيل الخروج - مسح التوكن
  static Future<void> logout() async {
    print('🚪 Logging out, clearing token');
    await clearToken();
  }

  // ================= DATA ENDPOINTS (Public - No Token Required) =================

  static Future<List<dynamic>> getStudentsPublic() async {
    print('📚 Fetching students (public)...');

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/students-public'),
    );

    print('   Response status: $res.statusCode');
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getDoctorsPublic() async {
    print('👨‍⚕️ Fetching doctors (public)...');

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/doctors-public'),
    );

    print('   Response status: $res.statusCode');
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getSubjectsPublic() async {
    print('📖 Fetching subjects (public)...');

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/subjects-public'),
    );

    print('   Response status: $res.statusCode');
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getLecturesPublic() async {
    print('🎓 Fetching lectures (public)...');

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/lectures-public'),
    );

    print('   Response status: ${res.statusCode}');
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  // ================= DATA ENDPOINTS (Authenticated) =================

  static Future<List<dynamic>> getStudents() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.studentsEndpoint}'),
      headers: _headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getDoctors() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.doctorsEndpoint}'),
      headers: _headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getSubjects() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.subjectsEndpoint}'),
      headers: _headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getLectures() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.lecturesEndpoint}'),
      headers: _headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getLecturesBySemester(int semester) async {
    try {
      print('🎓 Fetching lectures for semester $semester...');
      print('   Token available: $hasValidToken');

      final response = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}${AppConstants.lecturesEndpoint}?semester=$semester'),
        headers: _headers,
      );

      print('   Response status: $response.statusCode');
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      print('❌ Error loading lectures: $e');
      return [];
    }
  }

  static Future<int> getCurrentSemester() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/system/semester-mode'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['semester'] ?? 1;
      }
      return 1;
    } catch (e) {
      print('❌ Error getting semester: $e');
      return 1;
    }
  }

  static const String _cachedAcademicYearKey = 'system_academic_year';

  // Called by WebSocket when admin updates the academic year
  static Future<void> persistAcademicYear(String year) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedAcademicYearKey, year);
    print('💾 Academic year persisted: $year');
  }

  static Future<String> getCurrentAcademicYear() async {
    // 1. Try HTTP (semester-mode — no auth, same source as WebSocket broadcasts)
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/system/semester-mode'),
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final yr = d['academicYear'] ?? d['academic_year'] ??
            d['year'] ?? d['current_academic_year'] ?? d['currentAcademicYear'];
        if (yr != null && yr.toString().contains('-')) {
          await persistAcademicYear(yr.toString());
          return yr.toString();
        }
      }
    } catch (_) {}

    // 2. Try academic/settings (with auth)
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/academic/settings'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final yr = d['current_academic_year'] ?? d['academicYear'] ??
            d['academic_year'] ?? d['year'];
        if (yr != null && yr.toString().contains('-')) {
          await persistAcademicYear(yr.toString());
          return yr.toString();
        }
      }
    } catch (_) {}

    // 3. Fallback: last value set by admin via WebSocket (persisted in SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedAcademicYearKey);
    if (cached != null && cached.contains('-')) {
      print('📦 Academic year loaded from cache: $cached');
      return cached;
    }

    return '2026-2027';
  }

  // ✅ FIXED: attendance with proper token handling
  static Future<List<dynamic>> getAttendance([String? token]) async {
    final effectiveToken = token ?? _token;

    final headers = {
      'Content-Type': 'application/json',
    };

    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveToken';
      print('🔐 Token attached to attendance request');
    } else {
      print('⚠️ No token available for attendance request');
    }

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.attendanceEndpoint}'),
      headers: headers,
    );
    print('📡 Attendance response: ${res.statusCode}');
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  // ================= GRADES ENDPOINTS =================

  static Future<List<dynamic>> getStudentGrades(int studentId) async {
    final res = await http.get(
      Uri.parse(
          '${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/visible'),
      headers: _headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getStudentGradesWithToken(
      int studentId, String token) async {
    try {
      print('📊 Fetching grades for student $studentId with provided token');

      final response = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/visible'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📊 Grades API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Failed to load grades: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading grades: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> checkGradesStatus(
      int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/debug'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Failed to get status'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ================= GRADE DISTRIBUTION =================

  static Future<Map<String, double>?> getGradeDistribution(
      int doctorId, int subjectId, String token) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}/api/grade-distributions/$doctorId/$subjectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'midterm': (data['midterm'] ?? 10).toDouble(),
          'oral': (data['oral'] ?? 5).toDouble(),
          'practical': (data['practical'] ?? 20).toDouble(),
          'attendance': (data['attendance'] ?? 5).toDouble(),
          'assignment': (data['assignment'] ?? 10).toDouble(),
          'final': (data['final'] ?? 50).toDouble(),
        };
      }
    } catch (e) {
      print('Error fetching grade distribution: $e');
    }
    return null;
  }

  // ================= QR CODE =================

  static Future<Map<String, dynamic>> getStudentQRCode(
      int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/student/qrcode/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
            '✅ QR Code loaded for student: ${data['qrCode']?['student_name'] ?? studentId}');
        return data;
      } else {
        return {'success': false, 'error': 'Failed to get QR code'};
      }
    } catch (e) {
      print('❌ Error loading QR code: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> recordQRCodeScan(
      int studentId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/student/qrcode/scan/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to record scan'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDoctorQRCodes(
      int doctorId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/doctor/qrcodes/$doctorId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Failed to get QR codes'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= CHANGE PASSWORD =================

  static Future<Map<String, dynamic>> changeStudentPassword(
      String studentId, String newPassword, String token) async {
    try {
      print('🔄 Changing password for student: $studentId');
      print('   New password length: ${newPassword.length}');

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/student/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_id': studentId,
          'new_password': newPassword,
        }),
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error': errorData['error'] ?? 'Failed to change password'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      print('❌ Error changing password: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= ACADEMIC ENDPOINTS =================

  static Future<Map<String, dynamic>> getAcademicSettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/academic/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching academic settings: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getStudentEnrollmentStatus(
      int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/enrollment/status/$studentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching enrollment status: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getAvailableSubjectsForEnrollment(
      int studentId, int semester, String token) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}/api/enrollment/available/$studentId/$semester'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching available subjects: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> registerForSubject(
      Map<String, dynamic> enrollmentData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/enrollment/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(enrollmentData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Registration failed'};
    } catch (e) {
      print('Error registering for subject: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> dropSubject(
      Map<String, dynamic> dropData, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/enrollment/drop'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(dropData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Drop failed'};
    } catch (e) {
      print('Error dropping subject: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= TEACHING ASSISTANTS =================

  static Future<List<dynamic>> getTeachingAssistantsForDoctor(
      int doctorId) async {
    // Try authenticated endpoint first
    try {
      final res = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}/api/doctor/$doctorId/teaching-assistants'),
        headers: _headers,
      );
      print('👥 TAs API status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<dynamic>? list;
        if (data is List) list = data;
        if (data is Map && data['teachingAssistants'] is List) {
          list = data['teachingAssistants'];
        }
        if (list != null && list.isNotEmpty) return list;
      }
    } catch (e) {
      print('⚠️ TAs API failed: $e');
    }

    // Fallback: read teaching_assistants.json and filter by supervisor_doctor_id
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/database/teaching_assistants.json'),
        headers: _headers,
      );
      print('👥 TAs JSON status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .where((ta) =>
                  ta is Map &&
                  (ta['supervisor_doctor_id'] == doctorId ||
                      ta['supervisorDoctorId'] == doctorId))
              .toList();
        }
      }
    } catch (e) {
      print('❌ Error fetching TAs JSON: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> getTAPermissions(int taId) async {
    // Try authenticated endpoint first
    try {
      final res = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}/api/teaching-assistant/$taId/permissions'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          if (data['permissions'] is Map) {
            return Map<String, dynamic>.from(data['permissions']);
          }
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      print('⚠️ Permissions API failed: $e');
    }

    // Fallback: read ta_permissions.json
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/database/ta_permissions.json'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          final entry = data.firstWhere(
            (e) => e is Map && e['taId'] == taId,
            orElse: () => null,
          );
          if (entry != null && entry['permissions'] is Map) {
            return Map<String, dynamic>.from(entry['permissions']);
          }
        }
      }
    } catch (e) {
      print('❌ Error fetching permissions JSON: $e');
    }
    return {};
  }

  /// Returns `{success: bool, status: int?, error: String?}` so the UI can show
  /// the real reason (401/403/400/network) instead of a generic "Failed".
  static Future<Map<String, dynamic>> updateTAPermissions(
      int taId, Map<String, dynamic> permissions) async {
    final url =
        '${AppConstants.baseUrl}/api/teaching-assistant/$taId/permissions';
    try {
      final res = await http.put(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({'permissions': permissions}),
      );
      print('🔧 PUT $url → ${res.statusCode}: ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true, 'status': res.statusCode};
      }
      String error = 'HTTP ${res.statusCode}';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['error'] != null) {
          error = '${res.statusCode}: ${body['error']}';
        }
      } catch (_) {
        if (res.body.isNotEmpty) {
          error =
              '${res.statusCode}: ${res.body.substring(0, res.body.length > 120 ? 120 : res.body.length)}';
        }
      }
      return {'success': false, 'status': res.statusCode, 'error': error};
    } catch (e) {
      print('❌ PUT $url threw: $e');
      return {'success': false, 'error': 'Network: $e'};
    }
  }

  // ================= SYNC STATUS (Polling Fallback) =================

  static Future<Map<String, dynamic>> getSyncStatus(int lastUpdate) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}/api/sync/status?lastUpdate=$lastUpdate'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'hasUpdates': false};
    } catch (e) {
      print('Error checking sync status: $e');
      return {'hasUpdates': false};
    }
  }

  // ================= MOBILE UPDATES (SSE / Polling) =================

  static Future<Map<String, dynamic>> checkForMobileUpdates(
      String token, int lastTimestamp) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppConstants.baseUrl}/api/mobile/notify/poll?lastTimestamp=$lastTimestamp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return {'hasUpdate': false};
  }
}