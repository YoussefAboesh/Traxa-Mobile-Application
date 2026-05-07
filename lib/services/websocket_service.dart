// lib/services/websocket_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;

  // ✅ Stream للأحداث المختلفة عشان كل شاشة تستمع لللي يخصها
  final _dataChangeController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataChangeStream =>
      _dataChangeController.stream;

  final _semesterController = StreamController<int>.broadcast();
  Stream<int> get semesterStream => _semesterController.stream;

  final _academicYearController = StreamController<String>.broadcast();
  Stream<String> get academicYearStream => _academicYearController.stream;

  final _gradeUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get gradeUpdateStream =>
      _gradeUpdateController.stream;

  final _sessionActivatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sessionActivatedStream =>
      _sessionActivatedController.stream;

  final _sessionEndedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sessionEndedStream =>
      _sessionEndedController.stream;

  final _reportSavedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get reportSavedStream =>
      _reportSavedController.stream;

  final _registrationApprovedController =
      StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get registrationApprovedStream =>
      _registrationApprovedController.stream;

  final _levelsPromotedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get levelsPromotedStream =>
      _levelsPromotedController.stream;

  WebSocketService._();

  Future<void> connect() async {
    if (_isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userData = prefs.getString('user_data');

    if (token == null || userData == null) return;

    final user = jsonDecode(userData);
    final userId = user['id'];
    final userName = user['name'] ?? user['username'];
    final userRole = user['role'] ?? user['userType'] ?? 'guest';

    String clientType = 'mobile';
    if (userRole == 'doctor') {
      clientType = 'mobile-doctor';
    } else if (userRole == 'student') {
      clientType = 'mobile-student';
    }

    final wsUrl = '${AppConstants.wsUrl}?type=mobile';

    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
          _reconnectAttempts = 0;
        },
        onDone: () {
          print('📡 WebSocket disconnected');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      await Future.delayed(const Duration(milliseconds: 500));

      sendMessage({
        'type': 'REGISTER',
        'clientType': clientType,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'timestamp': DateTime.now().toIso8601String()
      });

      _startHeartbeat();
      print('✅ WebSocket connected and registered');
    } catch (e) {
      print('❌ WebSocket connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      print('📨 WebSocket received: ${data['type']}');

      // بث لكل المستمعين
      _dataChangeController.add(data);

      switch (data['type']) {
        case 'CONNECTION_ESTABLISHED':
          print('✅ Connected with ID: ${data['clientId']}');
          break;

        case 'REGISTERED':
          print('✅ Registered to WebSocket server');
          break;

        case 'PING':
          sendMessage({
            'type': 'PONG',
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
          break;

        case 'HEARTBEAT_ACK':
          break;

        case 'DATA_CHANGE':
          _handleDataChange(data);
          break;

        case 'SEMESTER_CHANGED':
          final semester = data['value'] ?? data['semester'];
          if (semester != null) {
            print('📢 Semester changed to: $semester');
            _semesterController.add(semester as int);
          }
          break;

        case 'ACADEMIC_YEAR_CHANGED':
          final year = data['value'] ?? data['academicYear'];
          if (year != null) {
            print('📢 Academic year changed to: $year');
            _academicYearController.add(year.toString());
          }
          break;

        case 'SESSION_ACTIVATED':
          print('📢 Session activated: ${data['session']?['subjectName']}');
          _sessionActivatedController.add(data);
          break;

        case 'SESSION_ENDED':
          print('📢 Session ended: ${data['sessionId']}');
          _sessionEndedController.add(data);
          break;

        case 'REPORT_SAVED':
          print('📢 Report saved for session: ${data['report']?['sessionId']}');
          _reportSavedController.add(data);
          break;

        case 'GRADE_UPDATED':
          print('📢 Grade updated: ${data['subjectId']}');
          _gradeUpdateController.add(data);
          break;

        case 'REGISTRATION_APPROVED':
          final subjects = data['approvedSubjects'] as List?;
          if (subjects != null) {
            print('📢 Registration approved for ${subjects.length} subjects');
            _registrationApprovedController.add(subjects);
          }
          break;

        case 'LEVELS_PROMOTED':
          print('📢 Levels promoted');
          _levelsPromotedController.add(data);
          break;

        case 'FULL_SYNC':
          print('📢 Full sync requested');
          _dataChangeController.add(data);
          break;

        default:
          print('📢 Unknown message type: ${data['type']}');
      }
    } catch (e) {
      print('❌ Error parsing WebSocket message: $e');
    }
  }

  void _handleDataChange(Map<String, dynamic> data) {
    final entity = data['entity'] as String?;
    final action = data['action'] as String?;

    print('🔄 Data change: $entity / $action');

    switch (entity) {
      case 'grade':
        if (action == 'created' || action == 'updated') {
          final gradeData = data['data'] as Map<String, dynamic>?;
          if (gradeData != null) {
            _gradeUpdateController.add(gradeData);
          }
        }
        break;

      case 'academic-settings':
        if (action == 'semester-switched') {
          final settings = data['data'] as Map<String, dynamic>?;
          if (settings != null) {
            _semesterController.add(settings['newSemester'] as int);
          }
        }
        break;

      case 'academic':
        if (action == 'levels-promoted') {
          _levelsPromotedController.add(data);
        }
        break;

      case 'registration-request':
        if (action == 'approved') {
          final requestData = data['data'] as Map<String, dynamic>?;
          if (requestData != null) {
            final subjects = requestData['subjects'] as List?;
            if (subjects != null) {
              _registrationApprovedController.add(subjects);
            }
          }
        }
        break;

      case 'attendance-session':
        if (action == 'ended') {
          final sessionData = data['data'] as Map<String, dynamic>?;
          if (sessionData != null) {
            _sessionEndedController.add({
              'sessionId': sessionData['sessionId'],
              'doctorId': sessionData['doctorId'],
              'subjectName': sessionData['subjectName'],
              'endedAt': sessionData['endedAt']
            });
          }
        }
        break;
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
      print('📤 WebSocket sent: ${message['type']}');
    } else {
      print('⚠️ Cannot send message, WebSocket not connected');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected) {
        sendMessage({
          'type': 'HEARTBEAT',
          'timestamp': DateTime.now().millisecondsSinceEpoch
        });
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('❌ Max reconnect attempts reached');
      return;
    }
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: min(5 * (_reconnectAttempts + 1), 30));
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      print('🔄 Reconnecting WebSocket (attempt $_reconnectAttempts)...');
      connect();
    });
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_channel != null) {
      _channel!.sink.close();
    }
    _isConnected = false;
    print('🔌 WebSocket disconnected manually');

    // إغلاق الـ Streams
    _dataChangeController.close();
    _semesterController.close();
    _academicYearController.close();
    _gradeUpdateController.close();
    _sessionActivatedController.close();
    _sessionEndedController.close();
    _reportSavedController.close();
    _registrationApprovedController.close();
    _levelsPromotedController.close();
  }

  bool get isConnected => _isConnected;
}
