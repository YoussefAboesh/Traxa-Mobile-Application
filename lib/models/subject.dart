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
  final int? taId;
  final String? taName;

  const Subject({
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

  /// Falls back to 3 — the university default and the server default.
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

  Map<String, dynamic> toJson() => {
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

  Subject copyWith({
    int? id,
    String? code,
    String? name,
    int? doctorId,
    String? doctorName,
    int? level,
    int? semester,
    String? department,
    int? credits,
    int? creditHours,
    int? taId,
    String? taName,
  }) {
    return Subject(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      level: level ?? this.level,
      semester: semester ?? this.semester,
      department: department ?? this.department,
      credits: credits ?? this.credits,
      creditHours: creditHours ?? this.creditHours,
      taId: taId ?? this.taId,
      taName: taName ?? this.taName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subject &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          doctorId == other.doctorId &&
          doctorName == other.doctorName &&
          level == other.level &&
          semester == other.semester &&
          department == other.department &&
          credits == other.credits &&
          creditHours == other.creditHours &&
          taId == other.taId &&
          taName == other.taName;

  @override
  int get hashCode => Object.hash(
        id,
        code,
        name,
        doctorId,
        doctorName,
        level,
        semester,
        department,
        credits,
        creditHours,
        taId,
        taName,
      );

  @override
  String toString() =>
      'Subject(id: $id, code: $code, name: $name, semester: $semester)';
}
