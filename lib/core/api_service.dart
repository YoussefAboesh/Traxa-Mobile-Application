// lib/core/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiService {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // ================= LOGIN =================

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.loginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setToken(data['token']);
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> studentLogin(
      String studentId, String password, bool isFirstLogin) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.studentLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': studentId,
          'password': password,
          'isFirstLogin': isFirstLogin,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setToken(data['token']);
        return {
          'success': true,
          'token': data['token'],
          'student': data['student'],
        };
      } else {
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> doctorLogin(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.doctorLoginEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setToken(data['token']);
        return {
          'success': true,
          'token': data['token'],
          'user': data['user'],
        };
      } else {
        return {'success': false, 'error': data['error']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= DATA =================

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
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.lecturesEndpoint}?semester=$semester'),
        headers: _headers,
      );
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

  static Future<List<dynamic>> getAttendance([String? token]) async {
    final headers = Map<String, String>.from(_headers);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.attendanceEndpoint}'),
      headers: headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getStudentGrades(int studentId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/visible'),
      headers: _headers,
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : [];
  }

  static Future<List<dynamic>> getStudentGradesWithToken(int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/visible'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('📊 Grades API Response Status: ${response.statusCode}');
      print('📊 Grades API Response Body: ${response.body}');
      
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
  
  static Future<Map<String, dynamic>> checkGradesStatus(int studentId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.gradesEndpoint}/$studentId/debug'),
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

  // ================= QR CODE =================

  static Future<Map<String, dynamic>> getStudentQRCode(int studentId, String token) async {
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
        print('✅ QR Code loaded for student: ${data['qrCode']?['student_name'] ?? studentId}');
        return data;
      } else {
        return {'success': false, 'error': 'Failed to get QR code'};
      }
    } catch (e) {
      print('❌ Error loading QR code: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> recordQRCodeScan(int studentId, String token) async {
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

  static Future<Map<String, dynamic>> getDoctorQRCodes(int doctorId, String token) async {
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

  static Future<Map<String, dynamic>> changeStudentPassword(String studentId, String newPassword, String token) async {
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
      print('📡 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {'success': false, 'error': errorData['error'] ?? 'Failed to change password'};
        } catch (e) {
          return {'success': false, 'error': 'Server error: ${response.statusCode}'};
        }
      }
    } catch (e) {
      print('❌ Error changing password: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}