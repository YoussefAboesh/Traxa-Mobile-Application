// lib/core/api_service.dart
// ignore_for_file: empty_catches

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';
import 'constants.dart';

class ApiService {
  static String? _token;
  static bool _isInitialized = false;

  // ================= TOKEN MANAGEMENT =================

  static Future<void> initToken() async {
    if (_isInitialized) return;

    try {
      _token = await SecureStorageService.getToken();
      _isInitialized = true;
    } catch (e) {
      print('❌ Error loading token: $e');
      _isInitialized = true;
    }
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    try {
      if (token != null && token.isNotEmpty) {
        await SecureStorageService.saveToken(token);
      } else {
        await SecureStorageService.deleteToken();
      }
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  static Future<void> clearToken() async {
    _token = null;
    try {
      await SecureStorageService.deleteToken();
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

  static String? getToken() => _token;

  static bool get hasValidToken => _token != null && _token!.isNotEmpty;

  static Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // ================= LOGIN =================

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.loginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await setToken(data['token']);
        return {'success': true, 'token': data['token'], 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> studentLogin(String studentId, String password, bool isFirstLogin) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.studentLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': studentId, 'password': password, 'isFirstLogin': isFirstLogin}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await setToken(data['token']);
        return {'success': true, 'token': data['token'], 'student': data['student']};
      } else {
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> doctorLogin(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.doctorLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await setToken(data['token']);
        return {'success': true, 'token': data['token'], 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<void> logout() async => await clearToken();

  // ================= DATA ENDPOINTS (Public) =================

  static Future<List<dynamic>> getStudentsPublic() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/students-public'));
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getDoctorsPublic() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/doctors-public'));
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getSubjectsPublic() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/subjects-public'));
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getLecturesPublic() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/lectures-public'));
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  // ================= DATA ENDPOINTS (Authenticated) =================

  static Future<List<dynamic>> getStudents() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}${AppConstants.studentsEndpoint}'), headers: _headers);
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getDoctors() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}${AppConstants.doctorsEndpoint}'), headers: _headers);
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getSubjects() async {
    // Prefer the public enriched endpoint: it returns `ta_name` + `doctor_name`
    // already joined (exactly like the web dashboard) and never returns 403.
    // The raw /database/subjects.json only has `ta_id`, so the TA name would
    // never resolve without it.
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/subjects-public'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          print('📚 Loaded ${data.length} subjects (enriched)');
          return data;
        }
      }
      print('⚠️ subjects-public => ${res.statusCode}, trying raw file...');
    } catch (e) {
      print('⚠️ subjects-public exception: $e, trying raw file...');
    }

    // Fallback: raw static file.
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.subjectsEndpoint}'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getLectures() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}${AppConstants.lecturesEndpoint}'), headers: _headers);
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getLecturesBySemester(int semester) async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}${AppConstants.lecturesEndpoint}?semester=$semester'), headers: _headers);
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  // ================= SECTIONS API =================

  static Future<List<dynamic>> getSections() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/sections'), headers: _headers);
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getSectionsBySemester(int semester) async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/sections?semester=$semester'), headers: _headers);
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  // ================= TEACHING ASSISTANTS =================

  static Future<List<dynamic>> getTeachingAssistants() async {
    // 1) Doctor-accessible endpoint (admin / it / doctor).
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/teaching-assistants-list'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          print('👥 Loaded ${data.length} TAs from list endpoint');
          return data;
        }
      }
      print('⚠️ TA list endpoint => ${res.statusCode}, trying fallback...');
    } catch (e) {
      print('⚠️ TA list exception: $e, trying fallback...');
    }

    // 2) Original endpoint (admin / it / mng / emp).
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/teaching-assistants'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          print('👥 Loaded ${data.length} TAs from main endpoint');
          return data;
        }
      }
      print('⚠️ TA main endpoint => ${res.statusCode}, trying static file...');
    } catch (e) {
      print('⚠️ TA main exception: $e, trying static file...');
    }

    // 3) Static public file — always accessible (students & TAs included).
    //    This is the same data served by /database, so it never returns 403.
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/database/teaching_assistants.json'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          print('👥 Loaded ${data.length} TAs from static file');
          return data;
        }
      }
      print('❌ TA static file => ${res.statusCode}');
    } catch (e) {
      print('❌ TA static file exception => $e');
    }

    print('❌ All TA sources failed — returning empty list');
    return [];
  }

  static Future<int> getCurrentSemester() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/system/semester-mode'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['semester'] ?? 1;
      }
      return 1;
    } catch (e) {
      return 1;
    }
  }

  static const String _cachedAcademicYearKey = 'system_academic_year';

  static Future<void> persistAcademicYear(String year) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedAcademicYearKey, year);
  }

  static Future<String> getCurrentAcademicYear() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/system/semester-mode'));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final yr = d['academicYear'] ?? d['academic_year'] ?? d['year'] ?? d['current_academic_year'] ?? d['currentAcademicYear'];
        if (yr != null && yr.toString().contains('-')) {
          await persistAcademicYear(yr.toString());
          return yr.toString();
        }
      }
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/academic/settings'), headers: _headers);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final yr = d['current_academic_year'] ?? d['academicYear'] ?? d['academic_year'] ?? d['year'];
        if (yr != null && yr.toString().contains('-')) {
          await persistAcademicYear(yr.toString());
          return yr.toString();
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedAcademicYearKey);
    if (cached != null && cached.contains('-')) return cached;

    return '2026-2027';
  }

  static Future<List<dynamic>> getAttendance([String? token]) async {
    final effectiveToken = token ?? _token;
    final headers = {'Content-Type': 'application/json'};
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveToken';
    }
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}${AppConstants.attendanceEndpoint}'), headers: headers);
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  // ================= GRADES ENDPOINTS =================

  static Future<List<dynamic>> getStudentGrades(int studentId) async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/visible'), headers: _headers);
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getStudentGradesWithToken(int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/visible'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> checkGradesStatus(int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/debug'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {'error': 'Failed to get status'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ================= GRADE DISTRIBUTION =================

  static Future<Map<String, double>?> getGradeDistribution(int doctorId, int subjectId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/grade-distributions/$doctorId/$subjectId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
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
    } catch (e) {}
    return null;
  }

  // ================= QR CODE =================

  static Future<Map<String, dynamic>> getStudentQRCode(int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/student/qrcode/$studentId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {'success': false, 'error': 'Failed to get QR code'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> recordQRCodeScan(int studentId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/student/qrcode/scan/$studentId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {'success': false, 'error': 'Failed to record scan'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDoctorQRCodes(int doctorId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/doctor/qrcodes/$doctorId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {'success': false, 'error': 'Failed to get QR codes'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= CHANGE PASSWORD =================

  static Future<Map<String, dynamic>> changeStudentPassword(String studentId, String newPassword, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/student/change-password'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'student_id': studentId, 'new_password': newPassword}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      try {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['error'] ?? 'Failed to change password'};
      } catch (e) {
        return {'success': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= ACADEMIC ENDPOINTS =================

  static Future<Map<String, dynamic>> getAcademicSettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/academic/settings'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getStudentEnrollmentStatus(int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/enrollment/status/$studentId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getAvailableSubjectsForEnrollment(int studentId, int semester, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/enrollment/available/$studentId/$semester'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> registerForSubject(Map<String, dynamic> enrollmentData, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/enrollment/register'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(enrollmentData),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {'success': false, 'error': 'Registration failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> dropSubject(Map<String, dynamic> dropData, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/enrollment/drop'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(dropData),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {'success': false, 'error': 'Drop failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= TEACHING ASSISTANTS FOR DOCTOR =================

  static Future<List<dynamic>> getTeachingAssistantsForDoctor(int doctorId) async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/doctor/$doctorId/teaching-assistants'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
        if (data is Map && data['teachingAssistants'] is List) return data['teachingAssistants'];
      }
    } catch (e) {}

    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/database/teaching_assistants.json'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.where((ta) => ta is Map && (ta['supervisor_doctor_id'] == doctorId || ta['supervisorDoctorId'] == doctorId)).toList();
        }
      }
    } catch (e) {}
    return [];
  }

  // ================= TA PERMISSIONS (OLD - per TA) =================

  static Future<Map<String, dynamic>> getTAPermissions(int taId) async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/api/teaching-assistant/$taId/permissions'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          if (data['permissions'] is Map) return Map<String, dynamic>.from(data['permissions']);
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {}

    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/database/ta_permissions.json'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          final entry = data.firstWhere((e) => e is Map && e['taId'] == taId, orElse: () => null);
          if (entry != null && entry['permissions'] is Map) return Map<String, dynamic>.from(entry['permissions']);
        }
      }
    } catch (e) {}
    return {};
  }

  static Future<Map<String, dynamic>> updateTAPermissions(int taId, Map<String, dynamic> permissions) async {
    final url = '${AppConstants.baseUrl}/api/teaching-assistant/$taId/permissions';
    try {
      final res = await http.put(Uri.parse(url), headers: _headers, body: jsonEncode({'permissions': permissions}));
      if (res.statusCode == 200 || res.statusCode == 201) return {'success': true, 'status': res.statusCode};
      return {'success': false, 'status': res.statusCode, 'error': 'HTTP ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network: $e'};
    }
  }

  // ================= TA SUBJECT PERMISSIONS (NEW - per subject) =================

  // The server stores per-subject TA permissions under these exact keys.
  // The UI works with the friendlier `can_activate_session` / `can_manage_grades`
  // names, so we translate in both directions here.
  static const String _kTaSessionPerm = 'ta.session.activate';
  static const String _kTaGradesPerm = 'ta.grades.manage';

  static Future<Map<String, dynamic>> getTASubjectPermissions(
      int taId, int subjectId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/ta-subject-permissions/$taId/$subjectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final perms = (data['permissions'] is Map)
            ? Map<String, dynamic>.from(data['permissions'])
            : <String, dynamic>{};
        return {
          'can_activate_session': perms[_kTaSessionPerm] ?? true,
          'can_manage_grades': perms[_kTaGradesPerm] ?? true,
        };
      }
      print('⚠️ getTASubjectPermissions => ${response.statusCode}');
      return {'can_activate_session': true, 'can_manage_grades': true};
    } catch (e) {
      print('❌ getTASubjectPermissions exception => $e');
      return {'can_activate_session': true, 'can_manage_grades': true};
    }
  }

  static Future<Map<String, dynamic>> updateTASubjectPermissions({
    required int taId,
    required int subjectId,
    required Map<String, dynamic> permissions,
    required String token,
  }) async {
    try {
      // Translate UI keys → server permission keys (accept either form).
      final serverPerms = {
        _kTaSessionPerm: permissions['can_activate_session'] ??
            permissions[_kTaSessionPerm] ??
            true,
        _kTaGradesPerm: permissions['can_manage_grades'] ??
            permissions[_kTaGradesPerm] ??
            true,
      };

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/ta-subject-permissions/$taId/$subjectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'permissions': serverPerms}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': 'Failed to update permissions (HTTP ${response.statusCode})'
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= AVATAR REMOVAL =================

  // 1×1 transparent PNG — used to register the avatar before deleting it.
  static final List<int> _blankPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNg'
      'AAIAAAUAAen63NgAAAAASUVORK5CYII=');

  /// Reliably removes a profile avatar.
  ///
  /// The server's DELETE endpoint only unlinks the file when
  /// `avatars_info.json` has a record for it — a photo uploaded from the web
  /// (or a record that drifted) won't be deleted and keeps coming back.
  /// To guarantee removal we first POST a tiny placeholder image (which
  /// re-creates that record) and then DELETE, so the file is really gone.
  ///
  /// [kind] is `'student'` or `'doctor'`.
  static Future<bool> forceRemoveAvatar({
    required String kind,
    required String id,
    required String token,
  }) async {
    final url = '${AppConstants.baseUrl}/api/$kind/avatar/$id';

    // 1) Register the avatar so the server's DELETE can find it.
    try {
      final req = http.MultipartRequest('POST', Uri.parse(url));
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes(
        'avatar',
        _blankPng,
        filename: 'blank.png',
        contentType: MediaType('image', 'png'),
      ));
      await req.send();
    } catch (e) {
      print('⚠️ Avatar placeholder upload failed: $e');
    }

    // 2) Now delete it for real.
    try {
      final res = await http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      print('🗑️ Avatar delete ($kind/$id) => ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      print('❌ Avatar delete failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> assignTAToSubject({
    required int subjectId,
    required int taId,
    required String token,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/subjects/$subjectId/assign-ta'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'ta_id': taId}),
      );
      
      if (response.statusCode == 200) {
        return {'success': true};
      }
      final errorData = jsonDecode(response.body);
      return {'success': false, 'error': errorData['error'] ?? 'Failed to assign TA'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> removeTAFromSubject({
    required int subjectId,
    required String token,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/subjects/$subjectId/assign-ta'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'ta_id': null}),
      );
      
      if (response.statusCode == 200) {
        return {'success': true};
      }
      final errorData = jsonDecode(response.body);
      return {'success': false, 'error': errorData['error'] ?? 'Failed to remove TA'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= SYNC STATUS =================

  static Future<Map<String, dynamic>> getSyncStatus(int lastUpdate) async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/sync/status?lastUpdate=$lastUpdate'), headers: _headers);
      return response.statusCode == 200 ? jsonDecode(response.body) : {'hasUpdates': false};
    } catch (e) {
      return {'hasUpdates': false};
    }
  }

  static Future<Map<String, dynamic>> checkForMobileUpdates(String token, int lastTimestamp) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/mobile/notify/poll?lastTimestamp=$lastTimestamp'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : {'hasUpdate': false};
    } catch (e) {
      return {'hasUpdate': false};
    }
  }
}