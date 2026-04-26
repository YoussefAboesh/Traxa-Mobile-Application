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

  AttendanceRecord({
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

  bool get isPresent => status == 'confirmed';
  bool get isPending => status == 'pending';
}