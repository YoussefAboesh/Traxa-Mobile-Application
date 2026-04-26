class Lecture {
  final int id;
  final int subjectId;
  final String subjectName;
  final int doctorId;
  final String doctorName;
  final int level;
  final String? department;
  final String day;
  final int timeslotId;
  final String timeDisplay;
  final int locationId;
  final String locationName;
  final bool active;

  Lecture({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.doctorId,
    required this.doctorName,
    required this.level,
    this.department,
    required this.day,
    required this.timeslotId,
    required this.timeDisplay,
    required this.locationId,
    required this.locationName,
    required this.active,
  });

  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      id: json['id'] ?? 0,
      subjectId: json['subject_id'] ?? 0,
      subjectName: json['subject_name'] ?? '',
      doctorId: json['doctor_id'] ?? 0,
      doctorName: json['doctor_name'] ?? '',
      level: json['level'] ?? 1,
      department: json['department'],
      day: json['day'] ?? '',
      timeslotId: json['timeslot_id'] ?? 0,
      timeDisplay: json['time_display'] ?? '',
      locationId: json['location_id'] ?? 0,
      locationName: json['location_name'] ?? '',
      active: json['active'] ?? true,
    );
  }
}