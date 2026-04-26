class Student {
  final int id;
  final String name;
  final String studentId;
  final int level;
  final String department;
  final Map<String, dynamic>? faceData;

  Student({
    required this.id,
    required this.name,
    required this.studentId,
    required this.level,
    required this.department,
    this.faceData,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      studentId: json['student_id'] ?? '',
      level: json['level'] ?? 1,
      department: json['department'] ?? 'General',
      faceData: json['face_data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'student_id': studentId,
      'level': level,
      'department': department,
      'face_data': faceData,
    };
  }
}