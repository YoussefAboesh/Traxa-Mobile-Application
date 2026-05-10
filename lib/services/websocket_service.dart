// lib/services/websocket_service.dart
// ✅ FIX: Improved reconnection and stream handling + Academic Year Support
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

  // ✅ Streams are re-initialized on connect, but listeners stay attached
  StreamController<Map<String, dynamic>>? _dataChangeController;
  StreamController<int>? _semesterController;
  StreamController<String>? _academicYearController;
  StreamController<Map<String, dynamic>>? _gradeUpdateController;
  StreamController<Map<String, dynamic>>? _sessionActivatedController;
  StreamController<Map<String, dynamic>>? _sessionEndedController;
  StreamController<Map<String, dynamic>>? _reportSavedController;
  StreamController<List<dynamic>>? _registrationApprovedController;
  StreamController<Map<String, dynamic>>? _levelsPromotedController;

  // Public getters for streams - ensures listeners never get closed streams
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

  WebSocketService._() {
    _initStreams();
  }

  void _initStreams() {
    // Don't close existing streams if they are still alive
    if (_dataChangeController != null && !_dataChangeController!.isClosed) {
      return;
    }
    
    // Create new streams
    _dataChangeController = StreamController<Map<String, dynamic>>.broadcast();
    _semesterController = StreamController<int>.broadcast();
    _academicYearController = StreamController<String>.broadcast();
    _gradeUpdateController = StreamController<Map<String, dynamic>>.broadcast();
    _sessionActivatedController = StreamController<Map<String, dynamic>>.broadcast();
    _sessionEndedController = StreamController<Map<String, dynamic>>.broadcast();
    _reportSavedController = StreamController<Map<String, dynamic>>.broadcast();
    _registrationApprovedController = StreamController<List<dynamic>>.broadcast();
    _levelsPromotedController = StreamController<Map<String, dynamic>>.broadcast();
    
    print('✅ WebSocket streams initialized');
  }


  Future<void> connect() async {
    // If already connected, don't reconnect
    if (_isConnected && _channel != null) {
      print('⚠️ WebSocket already connected');
      return;
    }

    // Ensure streams are ready before connection
    if (_dataChangeController == null || _dataChangeController!.isClosed) {
      _initStreams();
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userData = prefs.getString('user_data');

    if (token == null || userData == null) {
      print('⚠️ No token or user data, skipping WebSocket connection');
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

      // Add to main data change stream for general listeners
      if (_dataChangeController != null && !_dataChangeController!.isClosed) {
        _dataChangeController?.add(data);
      }

      switch (data['type']) {
        case 'CONNECTION_ESTABLISHED':
          print('✅ Connected with ID: ${data['clientId']}');
          break;
        case 'REGISTERED':
          print('✅ Registered to WebSocket server');
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
            print('📢 Semester changed to: $semester');
            if (_semesterController != null && !_semesterController!.isClosed) {
              _semesterController?.add(semester as int);
            }
          }
          break;
        case 'ACADEMIC_YEAR_CHANGED':
          // ✅ Handle academic year change from server broadcast
          final year = data['value'] ?? data['academicYear'];
          if (year != null) {
            print('📢 Academic year changed to: $year');
            if (_academicYearController != null && !_academicYearController!.isClosed) {
              _academicYearController?.add(year.toString());
            }
          }
          break;
        case 'SESSION_ACTIVATED':
          print('📢 Session activated: ${data['session']?['subjectName']}');
          if (_sessionActivatedController != null && !_sessionActivatedController!.isClosed) {
            _sessionActivatedController?.add(data);
          }
          break;
        case 'SESSION_ENDED':
          print('📢 Session ended: ${data['sessionId']}');
          if (_sessionEndedController != null && !_sessionEndedController!.isClosed) {
            _sessionEndedController?.add(data);
          }
          break;
        case 'REPORT_SAVED':
          print('📢 Report saved for session: ${data['report']?['sessionId']}');
          if (_reportSavedController != null && !_reportSavedController!.isClosed) {
            _reportSavedController?.add(data);
          }
          break;
        case 'GRADE_UPDATED':
          print('📢 Grade updated: ${data['subjectId']}');
          if (_gradeUpdateController != null && !_gradeUpdateController!.isClosed) {
            _gradeUpdateController?.add(data);
          }
          break;
        case 'REGISTRATION_APPROVED':
          final subjects = data['approvedSubjects'] as List?;
          if (subjects != null) {
            print('📢 Registration approved for ${subjects.length} subjects');
            if (_registrationApprovedController != null && !_registrationApprovedController!.isClosed) {
              _registrationApprovedController?.add(subjects);
            }
          }
          break;
        case 'LEVELS_PROMOTED':
          print('📢 Levels promoted');
          if (_levelsPromotedController != null && !_levelsPromotedController!.isClosed) {
            _levelsPromotedController?.add(data);
          }
          break;
        case 'FULL_SYNC':
          print('📢 Full sync requested');
          if (_dataChangeController != null && !_dataChangeController!.isClosed) {
            _dataChangeController?.add(data);
          }
          break;
        case 'TOKEN_EXPIRED':
          print('⚠️ Token expired - need to logout');
          if (_dataChangeController != null && !_dataChangeController!.isClosed) {
            _dataChangeController?.add({'type': 'TOKEN_EXPIRED'});
          }
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
            if (_gradeUpdateController != null && !_gradeUpdateController!.isClosed) {
              _gradeUpdateController?.add(gradeData);
            }
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
        if (action == 'academic-year-changed') {
          // ✅ Handle academic year change from DATA_CHANGE broadcast
          final yearData = data['data'] as Map<String, dynamic>?;
          if (yearData != null) {
            final newYear = yearData['newYear'] as String?;
            if (newYear != null) {
              print('📢 Academic year changed via DATA_CHANGE: $newYear');
              if (_academicYearController != null && !_academicYearController!.isClosed) {
                _academicYearController?.add(newYear);
              }
            }
          }
        } else if (action == 'levels-promoted') {
          if (_levelsPromotedController != null && !_levelsPromotedController!.isClosed) {
            _levelsPromotedController?.add(data);
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
      case 'attendance-session':
        if (action == 'ended') {
          final sessionData = data['data'] as Map<String, dynamic>?;
          if (sessionData != null) {
            if (_sessionEndedController != null && !_sessionEndedController!.isClosed) {
              _sessionEndedController?.add({
                'sessionId': sessionData['sessionId'],
                'doctorId': sessionData['doctorId'],
                'report': sessionData['report']
              });
            }
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
      if (_isConnected && _channel != null) {
        sendMessage({'type': 'HEARTBEAT', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('❌ Max reconnect attempts reached, giving up');
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
    print('🔌 Disconnecting WebSocket manually');
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    if (_channel != null) {
      try {
        _channel!.sink.close();
      } catch (e) {
        print('Error closing channel: $e');
      }
      _channel = null;
    }
    
    _isConnected = false;
    _reconnectAttempts = 0;
    
    // ✅ Don't close streams on disconnect - they will be reused on reconnect
    // This prevents listeners from being lost
    print('🔌 WebSocket disconnected manually, streams kept alive');
  }

  bool get isConnected => _isConnected;
}