class AttendanceRecord {
  final int id;
  final String sessionId;
  final int lectureId;
  final int studentId;
  final String studentName;
  final String studentIdNumber;
  final String subjectName;
  final String status;
  final String? confirmedBy;
  final String? confirmedAt;
  final String date;
  final String time;

  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.lectureId,
    required this.studentId,
    required this.studentName,
    required this.studentIdNumber,
    required this.subjectName,
    required this.status,
    this.confirmedBy,
    this.confirmedAt,
    required this.date,
    required this.time,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      sessionId: json['session_id'] ?? '',
      lectureId: json['lecture_id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      studentIdNumber: json['student_id_number'] ?? '',
      subjectName: json['subject_name'] ?? '',
      status: json['status'] ?? 'pending',
      confirmedBy: json['confirmed_by'],
      confirmedAt: json['confirmed_at'],
      date: json['date'] ?? '',
      time: json['time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'lecture_id': lectureId,
        'student_id': studentId,
        'student_name': studentName,
        'student_id_number': studentIdNumber,
        'subject_name': subjectName,
        'status': status,
        'confirmed_by': confirmedBy,
        'confirmed_at': confirmedAt,
        'date': date,
        'time': time,
      };

  AttendanceRecord copyWith({
    int? id,
    String? sessionId,
    int? lectureId,
    int? studentId,
    String? studentName,
    String? studentIdNumber,
    String? subjectName,
    String? status,
    String? confirmedBy,
    String? confirmedAt,
    String? date,
    String? time,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      lectureId: lectureId ?? this.lectureId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentIdNumber: studentIdNumber ?? this.studentIdNumber,
      subjectName: subjectName ?? this.subjectName,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      date: date ?? this.date,
      time: time ?? this.time,
    );
  }

  bool get isPresent => status == 'confirmed';
  bool get isPending => status == 'pending';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sessionId == other.sessionId &&
          lectureId == other.lectureId &&
          studentId == other.studentId &&
          studentName == other.studentName &&
          studentIdNumber == other.studentIdNumber &&
          subjectName == other.subjectName &&
          status == other.status &&
          confirmedBy == other.confirmedBy &&
          confirmedAt == other.confirmedAt &&
          date == other.date &&
          time == other.time;

  @override
  int get hashCode => Object.hashAll([
        id,
        sessionId,
        lectureId,
        studentId,
        studentName,
        studentIdNumber,
        subjectName,
        status,
        confirmedBy,
        confirmedAt,
        date,
        time,
      ]);

  @override
  String toString() =>
      'AttendanceRecord(studentId: $studentId, status: $status, date: $date)';
}
