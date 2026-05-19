class Subject {
  final int id;
  final String? code;
  final String name;
  final int doctorId;
  final String doctorName;
  final int level;
  final int semester;
  final String? department;
  final int? credits;
  final int? creditHours;
  // ── TA fields (from the subjects endpoint or joined) ──────────────────
  final int? taId;
  final String? taName;

  Subject({
    required this.id,
    this.code,
    required this.name,
    required this.doctorId,
    required this.doctorName,
    required this.level,
    required this.semester,
    this.department,
    this.credits,
    this.creditHours,
    this.taId,
    this.taName,
  });

  int get totalCreditHours {
    if (credits != null && credits! > 0) return credits!;
    if (creditHours != null && creditHours! > 0) return creditHours!;
    return 3;
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? 0,
      code: json['code'],
      name: json['name'] ?? '',
      doctorId: json['doctor_id'] ?? json['doctorId'] ?? 0,
      doctorName: json['doctor_name'] ?? json['doctorName'] ?? 'Not Assigned',
      level: json['level'] ?? 1,
      semester: json['semester'] ?? 1,
      department: json['department'],
      credits: json['credits'],
      creditHours: json['credit_hours'] ?? json['creditHours'],
      taId: json['ta_id'] ?? json['taId'] ?? json['teaching_assistant_id'],
      taName: json['ta_name'] ??
          json['taName'] ??
          json['teaching_assistant_name'] ??
          json['ta_username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'level': level,
      'semester': semester,
      'department': department,
      'credits': credits,
      'credit_hours': creditHours,
      'ta_id': taId,
      'ta_name': taName,
    };
  }
}
