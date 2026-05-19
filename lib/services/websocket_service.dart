import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'secure_storage_service.dart';
import '../core/logger.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;

  StreamController<Map<String, dynamic>>? _dataChangeController;
  StreamController<int>? _semesterController;
  StreamController<String>? _academicYearController;
  StreamController<Map<String, dynamic>>? _gradeUpdateController;
  StreamController<Map<String, dynamic>>? _sessionActivatedController;
  StreamController<Map<String, dynamic>>? _sessionEndedController;
  StreamController<Map<String, dynamic>>? _reportSavedController;
  StreamController<List<dynamic>>? _registrationApprovedController;
  StreamController<Map<String, dynamic>>? _levelsPromotedController;
  StreamController<Map<String, dynamic>>? _taPermissionsController;

  Stream<Map<String, dynamic>> get dataChangeStream {
    if (_dataChangeController == null || _dataChangeController!.isClosed) {
      _initStreams();
    }
    return _dataChangeController!.stream;
  }

  Stream<int> get semesterStream {
    if (_semesterController == null || _semesterController!.isClosed) {
      _initStreams();
    }
    return _semesterController!.stream;
  }

  Stream<String> get academicYearStream {
    if (_academicYearController == null || _academicYearController!.isClosed) {
      _initStreams();
    }
    return _academicYearController!.stream;
  }

  Stream<Map<String, dynamic>> get gradeUpdateStream {
    if (_gradeUpdateController == null || _gradeUpdateController!.isClosed) {
      _initStreams();
    }
    return _gradeUpdateController!.stream;
  }

  Stream<Map<String, dynamic>> get sessionActivatedStream {
    if (_sessionActivatedController == null || _sessionActivatedController!.isClosed) {
      _initStreams();
    }
    return _sessionActivatedController!.stream;
  }

  Stream<Map<String, dynamic>> get sessionEndedStream {
    if (_sessionEndedController == null || _sessionEndedController!.isClosed) {
      _initStreams();
    }
    return _sessionEndedController!.stream;
  }

  Stream<Map<String, dynamic>> get reportSavedStream {
    if (_reportSavedController == null || _reportSavedController!.isClosed) {
      _initStreams();
    }
    return _reportSavedController!.stream;
  }

  Stream<List<dynamic>> get registrationApprovedStream {
    if (_registrationApprovedController == null || _registrationApprovedController!.isClosed) {
      _initStreams();
    }
    return _registrationApprovedController!.stream;
  }

  Stream<Map<String, dynamic>> get levelsPromotedStream {
    if (_levelsPromotedController == null || _levelsPromotedController!.isClosed) {
      _initStreams();
    }
    return _levelsPromotedController!.stream;
  }

  Stream<Map<String, dynamic>> get taPermissionsStream {
    if (_taPermissionsController == null || _taPermissionsController!.isClosed) {
      _initStreams();
    }
    return _taPermissionsController!.stream;
  }

  WebSocketService._() {
    _initStreams();
  }

  void _initStreams() {
    if (_dataChangeController != null && !_dataChangeController!.isClosed) {
      return;
    }

    _dataChangeController = StreamController<Map<String, dynamic>>.broadcast();
    _semesterController = StreamController<int>.broadcast();
    _academicYearController = StreamController<String>.broadcast();
    _gradeUpdateController = StreamController<Map<String, dynamic>>.broadcast();
    _sessionActivatedController = StreamController<Map<String, dynamic>>.broadcast();
    _sessionEndedController = StreamController<Map<String, dynamic>>.broadcast();
    _reportSavedController = StreamController<Map<String, dynamic>>.broadcast();
    _registrationApprovedController = StreamController<List<dynamic>>.broadcast();
    _levelsPromotedController = StreamController<Map<String, dynamic>>.broadcast();
    _taPermissionsController = StreamController<Map<String, dynamic>>.broadcast();

    logDebug('✅ WebSocket streams initialized');
  }

  Future<void> connect() async {
    if (_isConnected && _channel != null) {
      logDebug('⚠️ WebSocket already connected');
      return;
    }

    if (_dataChangeController == null || _dataChangeController!.isClosed) {
      _initStreams();
    }

    final token = await SecureStorageService.getToken();
    final userData = await SecureStorageService.getUserData();

    if (token == null || token.isEmpty || userData == null) {
      logDebug('⚠️ No token or user data, skipping WebSocket connection');
      return;
    }

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
      final trustedHost = Uri.parse(AppConstants.baseUrl).host;
      final httpClient = HttpClient()
        ..badCertificateCallback =
            ((X509Certificate cert, String host, int port) =>
                host == trustedHost)
        ..connectionTimeout = const Duration(seconds: 10);

      final socket = await WebSocket.connect(wsUrl, customClient: httpClient)
          .timeout(const Duration(seconds: 12));

      _channel = IOWebSocketChannel(socket);
      _isConnected = true;
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
          _reconnectAttempts = 0;
        },
        onDone: () {
          logDebug('📡 WebSocket disconnected');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          logDebug('❌ WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      sendMessage({
        'type': 'REGISTER',
        'clientType': clientType,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'timestamp': DateTime.now().toIso8601String()
      });

      _startHeartbeat();
      logDebug('✅ WebSocket connected and registered');
    } catch (e) {
      logDebug('❌ WebSocket connection failed: $e');
      _isConnected = false;
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      logDebug('📨 WebSocket received: ${data['type']}');

      if (_dataChangeController != null && !_dataChangeController!.isClosed) {
        _dataChangeController?.add(data);
      }

      switch (data['type']) {
        case 'CONNECTION_ESTABLISHED':
          logDebug('✅ Connected with ID: ${data['clientId']}');
          break;
        case 'REGISTERED':
          logDebug('✅ Registered to WebSocket server');
          break;
        case 'PING':
          sendMessage({'type': 'PONG', 'timestamp': DateTime.now().millisecondsSinceEpoch});
          break;
        case 'HEARTBEAT_ACK':
          break;
        case 'DATA_CHANGE':
          _handleDataChange(data);
          break;
        case 'SEMESTER_CHANGED':
          final semester = data['value'] ?? data['semester'];
          if (semester != null) {
            logDebug('📢 Semester changed to: $semester');
            if (_semesterController != null && !_semesterController!.isClosed) {
              _semesterController?.add(semester as int);
            }
          }
          break;
        case 'ACADEMIC_YEAR_CHANGED':
          {
            final year = data['value'] ??
                data['academicYear'] ??
                data['academic_year'] ??
                data['year'] ??
                data['newYear'] ??
                data['current_academic_year'];
            if (year != null) {
              logDebug('📢 Academic year changed to: $year');
              _persistAcademicYear(year.toString());
              if (_academicYearController != null && !_academicYearController!.isClosed) {
                _academicYearController?.add(year.toString());
              }
            }
          }
          break;
        case 'SESSION_ACTIVATED':
          logDebug('📢 Session activated: ${data['session']?['subjectName']}');
          if (_sessionActivatedController != null && !_sessionActivatedController!.isClosed) {
            _sessionActivatedController?.add(data);
          }
          break;
        case 'SESSION_ENDED':
          logDebug('📢 Session ended: ${data['sessionId']}');
          if (_sessionEndedController != null && !_sessionEndedController!.isClosed) {
            _sessionEndedController?.add(data);
          }
          break;
        case 'REPORT_SAVED':
          logDebug('📢 Report saved for session: ${data['report']?['sessionId']}');
          if (_reportSavedController != null && !_reportSavedController!.isClosed) {
            _reportSavedController?.add(data);
          }
          break;
        case 'GRADE_UPDATED':
          logDebug('📢 Grade updated: ${data['subjectId']}');
          if (_gradeUpdateController != null && !_gradeUpdateController!.isClosed) {
            _gradeUpdateController?.add(data);
          }
          break;
        case 'REGISTRATION_APPROVED':
          final subjects = data['approvedSubjects'] as List?;
          if (subjects != null) {
            logDebug('📢 Registration approved for ${subjects.length} subjects');
            if (_registrationApprovedController != null && !_registrationApprovedController!.isClosed) {
              _registrationApprovedController?.add(subjects);
            }
          }
          break;
        case 'LEVELS_PROMOTED':
          logDebug('📢 Levels promoted');
          if (_levelsPromotedController != null && !_levelsPromotedController!.isClosed) {
            _levelsPromotedController?.add(data);
          }
          break;
        case 'FULL_SYNC':
          logDebug('📢 Full sync requested');
          if (_dataChangeController != null && !_dataChangeController!.isClosed) {
            _dataChangeController?.add(data);
          }
          break;
        case 'TOKEN_EXPIRED':
          logDebug('⚠️ Token expired - need to logout');
          if (_dataChangeController != null && !_dataChangeController!.isClosed) {
            _dataChangeController?.add({'type': 'TOKEN_EXPIRED'});
          }
          break;
        default:
          logDebug('📢 Unknown message type: ${data['type']}');
      }
    } catch (e) {
      logDebug('❌ Error parsing WebSocket message: $e');
    }
  }

  void _handleDataChange(Map<String, dynamic> data) {
    final entity = data['entity'] as String?;
    final action = data['action'] as String?;
    logDebug('🔄 Data change: $entity / $action');

    switch (entity) {
      case 'grade':
        {
          final gradeData = data['data'] as Map<String, dynamic>?;
          if (gradeData != null && _gradeUpdateController != null && !_gradeUpdateController!.isClosed) {
            _gradeUpdateController?.add(gradeData);
          }
        }
        break;
      case 'academic-settings':
        if (action == 'semester-switched') {
          final settings = data['data'] as Map<String, dynamic>?;
          if (settings != null) {
            if (_semesterController != null && !_semesterController!.isClosed) {
              _semesterController?.add(settings['newSemester'] as int);
            }
          }
        }
        break;
      case 'academic':
        if (action == 'levels-promoted') {
          if (_levelsPromotedController != null && !_levelsPromotedController!.isClosed) {
            _levelsPromotedController?.add(data);
          }
        } else {
          final yearData = data['data'] as Map<String, dynamic>?;
          final newYear = yearData?['newYear'] ??
              yearData?['academicYear'] ??
              yearData?['academic_year'] ??
              yearData?['year'] ??
              yearData?['current_academic_year'];
          if (newYear != null && _academicYearController != null && !_academicYearController!.isClosed) {
            logDebug('📢 Academic year changed via DATA_CHANGE ($action): $newYear');
            _persistAcademicYear(newYear.toString());
            _academicYearController?.add(newYear.toString());
          }
        }
        break;
      case 'teaching-assistant':
        if (action == 'permissions-updated') {
          final taData = data['data'] as Map<String, dynamic>?;
          if (taData != null && _taPermissionsController != null && !_taPermissionsController!.isClosed) {
            _taPermissionsController?.add(taData);
          }
        }
        break;
      case 'registration-request':
        if (action == 'approved') {
          final requestData = data['data'] as Map<String, dynamic>?;
          if (requestData != null) {
            final subjects = requestData['subjects'] as List?;
            if (subjects != null) {
              if (_registrationApprovedController != null && !_registrationApprovedController!.isClosed) {
                _registrationApprovedController?.add(subjects);
              }
            }
          }
        }
        break;
      case 'system':
        {
          final systemData = data['data'] as Map<String, dynamic>?;
          if (systemData != null) {
            final semester = systemData['semester'] as int?;
            if (semester != null && _semesterController != null && !_semesterController!.isClosed) {
              logDebug('📢 System: semester changed to S$semester');
              _semesterController?.add(semester);
            }
            final academicYear = systemData['academicYear'] ??
                systemData['academic_year'] ??
                systemData['year'] ??
                systemData['current_academic_year'] ??
                systemData['newYear'];
            if (academicYear != null && _academicYearController != null && !_academicYearController!.isClosed) {
              logDebug('📢 System: academic year changed to $academicYear');
              _persistAcademicYear(academicYear.toString());
              _academicYearController?.add(academicYear.toString());
            }
          }
        }
        break;
      case 'attendance-session':
      case 'active-session':
        if (action == 'created' || action == 'qr-phase-started') {
          final sessionData = data['data'] as Map<String, dynamic>?;
          if (sessionData != null && _sessionActivatedController != null && !_sessionActivatedController!.isClosed) {
            _sessionActivatedController?.add({'session': sessionData, 'action': action});
          }
        } else if (action == 'ended') {
          final sessionData = data['data'] as Map<String, dynamic>?;
          if (sessionData != null) {
            if (_sessionEndedController != null && !_sessionEndedController!.isClosed) {
              _sessionEndedController?.add({
                'sessionId': sessionData['sessionId'],
                'doctorId': sessionData['doctorId'],
              });
            }
          }
        }
        break;
    }
  }

  void _persistAcademicYear(String year) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('system_academic_year', year);
      logDebug('💾 Academic year persisted via WS: $year');
    });
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
      logDebug('📤 WebSocket sent: ${message['type']}');
    } else {
      logDebug('⚠️ Cannot send message, WebSocket not connected');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected && _channel != null) {
        sendMessage({'type': 'HEARTBEAT', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _scheduleReconnect() {
    if (_isConnected) return;
    _reconnectTimer?.cancel();
    final delay = Duration(
        seconds: min(5 * (min(_reconnectAttempts, maxReconnectAttempts) + 1), 30));
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      logDebug('🔄 Reconnecting WebSocket (attempt $_reconnectAttempts)...');
      connect();
    });
  }

  void disconnect() {
    logDebug('🔌 Disconnecting WebSocket manually');
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      try {
        _channel!.sink.close();
      } catch (e) {
        logDebug('Error closing channel: $e');
      }
      _channel = null;
    }

    _isConnected = false;
    _reconnectAttempts = 0;

    logDebug('🔌 WebSocket disconnected manually, streams kept alive');
  }

  bool get isConnected => _isConnected;
}
