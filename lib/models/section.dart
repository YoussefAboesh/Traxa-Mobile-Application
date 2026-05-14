// lib/models/section.dart
//
// السكاشن بتيجي من نفس الـ lectures endpoint —
// الـ backend بيرجع كل row ومنهم اللي عندهم
//   type == 'section'  أو  is_section == true  أو  lecture_type == 'section'
// لو الـ backend ملوش الـ field ده، مفيش sections هتتعرض.

class Section {
  final int id;
  final int subjectId;
  final String subjectName;
  final int? taId;
  final String taName;
  final String day;
  final String startTime;
  final String endTime;
  final String locationName;
  final int level;
  final String? department;

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
  });

  String get timeDisplay => '$startTime - $endTime';

  /// بنبني Section من الـ raw JSON اللي بييجي من الـ lectures endpoint
  factory Section.fromJson(Map<String, dynamic> json) {
    final taName = (json['ta_name'] ??
            json['taName'] ??
            json['teaching_assistant_name'] ??
            json['doctor_name'] ??
            json['doctorName'] ??
            'Unknown')
        .toString();

    final rawTaId = json['ta_id'] ??
        json['taId'] ??
        json['teaching_assistant_id'] ??
        json['doctor_id'] ??
        json['doctorId'];

    final startTime = (json['start_time'] ??
            json['startTime'] ??
            json['time_start'] ??
            '')
        .toString();

    final endTime = (json['end_time'] ??
            json['endTime'] ??
            json['time_end'] ??
            '')
        .toString();

    final locationName = (json['location_name'] ??
            json['locationName'] ??
            json['hall'] ??
            json['room'] ??
            json['location'] ??
            'TBA')
        .toString();

    return Section(
      id: json['id'] ?? 0,
      subjectId: json['subject_id'] ?? json['subjectId'] ?? 0,
      subjectName: (json['subject_name'] ??
              json['subjectName'] ??
              json['name'] ??
              'Unknown')
          .toString(),
      taId: rawTaId is int
          ? rawTaId
          : int.tryParse(rawTaId?.toString() ?? ''),
      taName: taName,
      day: (json['day'] ?? '').toString(),
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      level: json['level'] ?? 1,
      department: json['department']?.toString(),
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
      };

  /// هل الـ JSON row ده section؟
  /// بيشوف الـ type field بكل أشكاله الممكنة
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
