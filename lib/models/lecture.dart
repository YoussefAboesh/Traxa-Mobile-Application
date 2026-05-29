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

  const Lecture({
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'level': level,
        'department': department,
        'day': day,
        'timeslot_id': timeslotId,
        'time_display': timeDisplay,
        'location_id': locationId,
        'location_name': locationName,
        'active': active,
      };

  Lecture copyWith({
    int? id,
    int? subjectId,
    String? subjectName,
    int? doctorId,
    String? doctorName,
    int? level,
    String? department,
    String? day,
    int? timeslotId,
    String? timeDisplay,
    int? locationId,
    String? locationName,
    bool? active,
  }) {
    return Lecture(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      level: level ?? this.level,
      department: department ?? this.department,
      day: day ?? this.day,
      timeslotId: timeslotId ?? this.timeslotId,
      timeDisplay: timeDisplay ?? this.timeDisplay,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lecture &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          subjectId == other.subjectId &&
          subjectName == other.subjectName &&
          doctorId == other.doctorId &&
          doctorName == other.doctorName &&
          level == other.level &&
          department == other.department &&
          day == other.day &&
          timeslotId == other.timeslotId &&
          timeDisplay == other.timeDisplay &&
          locationId == other.locationId &&
          locationName == other.locationName &&
          active == other.active;

  @override
  int get hashCode => Object.hash(
        id,
        subjectId,
        subjectName,
        doctorId,
        doctorName,
        level,
        department,
        day,
        timeslotId,
        timeDisplay,
        locationId,
        locationName,
        active,
      );

  @override
  String toString() =>
      'Lecture(id: $id, subject: $subjectName, day: $day, time: $timeDisplay)';
}
