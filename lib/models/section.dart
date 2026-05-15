// lib/models/section.dart
//
// السكاشن بتيجي من الـ sections endpoint —
// الـ backend بيرجع البيانات في صيغة JSON

class Section {
  final int id;
  final int subjectId;
  final String subjectName;
  final int? taId;
  String taName;  // can be updated after fetching from API
  final String day;
  final String startTime;
  final String endTime;
  final String locationName;
  final int level;
  final String? department;
  final String? rawTimeDisplay;
  final int? semester;  // ✅ Changed to nullable int

  Section({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    this.taId,
    required this.taName,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    required this.level,
    this.department,
    this.rawTimeDisplay,
    this.semester,  // ✅ not required, can be null
  });

  String get timeDisplay {
    // Use raw time display if available from API
    if (rawTimeDisplay != null && rawTimeDisplay!.isNotEmpty) {
      return rawTimeDisplay!;
    }
    
    // Otherwise build from start/end times
    if (endTime.isEmpty) {
      return startTime;
    }
    
    return '$startTime - $endTime';
  }

  /// بنبني Section من الـ raw JSON اللي بييجي من الـ sections endpoint
  factory Section.fromJson(Map<String, dynamic> json) {
    // محاولة جلب وقت العرض المباشر أولاً (nullable)
    final rawTimeDisplay = json['time_display']?.toString() ??
                           json['timeDisplay']?.toString() ??
                           json['time']?.toString();

    // محاولة جلب اسم المعيد من عدة مصادر
    String taName = '';
    
    final possibleTaNameKeys = [
      'ta_name',
      'taName',
      'teaching_assistant_name',
      'teachingAssistantName',
      'assistant_name',
      'assistantName',
      'doctor_name',
      'doctorName',
      'instructor_name',
      'instructorName',
      'teacher_name',
      'teacherName'
    ];
    
    for (final key in possibleTaNameKeys) {
      if (json[key] != null && json[key].toString().isNotEmpty) {
        taName = json[key].toString();
        break;
      }
    }

    // محاولة جلب الـ ta_id من عدة مصادر
    int? taId;
    final possibleTaIdKeys = ['ta_id', 'taId', 'teaching_assistant_id', 'teachingAssistantId'];
    for (final key in possibleTaIdKeys) {
      if (json[key] != null) {
        if (json[key] is int) {
          taId = json[key];
        } else if (json[key] is String && int.tryParse(json[key]) != null) {
          taId = int.tryParse(json[key]);
        }
        if (taId != null) break;
      }
    }

    // محاولة جلب وقت البداية والنهاية
    String startTime = '';
    String endTime = '';
    
    final possibleStartTimeKeys = [
      'start_time', 'startTime', 'time_start', 'timeStart', 
      'from', 'start'
    ];
    final possibleEndTimeKeys = [
      'end_time', 'endTime', 'time_end', 'timeEnd', 
      'to', 'end'
    ];
    
    for (final key in possibleStartTimeKeys) {
      if (json[key] != null && json[key].toString().isNotEmpty) {
        startTime = json[key].toString();
        break;
      }
    }
    
    for (final key in possibleEndTimeKeys) {
      if (json[key] != null && json[key].toString().isNotEmpty) {
        endTime = json[key].toString();
        break;
      }
    }

    // جلب اسم المكان
    String locationName = '';
    final possibleLocationKeys = [
      'location_name', 'locationName', 'hall', 'room', 'location', 
      'place', 'venue', 'classroom', 'building'
    ];
    
    for (final key in possibleLocationKeys) {
      if (json[key] != null && json[key].toString().isNotEmpty) {
        locationName = json[key].toString();
        break;
      }
    }
    
    if (locationName.isEmpty) {
      locationName = 'Location TBA';
    }

    // جلب اسم المادة
    String subjectName = '';
    final possibleSubjectKeys = [
      'subject_name', 'subjectName', 'name', 'title', 'course_name', 'courseName'
    ];
    
    for (final key in possibleSubjectKeys) {
      if (json[key] != null && json[key].toString().isNotEmpty) {
        subjectName = json[key].toString();
        break;
      }
    }
    
    if (subjectName.isEmpty) {
      subjectName = 'Unknown Subject';
    }

    // ✅ جلب الـ semester (مع handling للـ null)
    int? semester;
    final semesterValue = json['semester'] ?? json['subject_semester'];
    if (semesterValue is int) {
      semester = semesterValue;
    } else if (semesterValue is String) {
      semester = int.tryParse(semesterValue);
    }

    return Section(
      id: json['id'] ?? 0,
      subjectId: json['subject_id'] ?? json['subjectId'] ?? 0,
      subjectName: subjectName,
      taId: taId,
      taName: taName.isEmpty ? 'TA' : taName,
      day: json['day']?.toString() ?? '',
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      level: json['level'] ?? 1,
      department: json['department']?.toString(),
      rawTimeDisplay: rawTimeDisplay,
      semester: semester,  // ✅ can be null
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'ta_id': taId,
        'ta_name': taName,
        'day': day,
        'start_time': startTime,
        'end_time': endTime,
        'location_name': locationName,
        'level': level,
        'department': department,
        'time_display': rawTimeDisplay,
        'semester': semester,
      };

  /// هل الـ JSON row ده section؟
  static bool isSection(Map<String, dynamic> json) {
    final type = (json['type'] ??
            json['lecture_type'] ??
            json['lectureType'] ??
            json['kind'] ??
            '')
        .toString()
        .toLowerCase();
    final isSecFlag = json['is_section'] ?? json['isSection'];
    return type == 'section' ||
        type == 'sec' ||
        isSecFlag == true ||
        isSecFlag == 1 ||
        isSecFlag == '1';
  }
}