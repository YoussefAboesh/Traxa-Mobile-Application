class QrCode {
  final int id;
  final int studentId;
  final String studentName;
  final String studentCode;
  final int studentLevel;
  final String studentDepartment;
  final String qrData;
  final String encodedData;
  final DateTime generatedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int scanCount;
  final DateTime? lastScannedAt;
  final int version;

  const QrCode({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.studentLevel,
    required this.studentDepartment,
    required this.qrData,
    required this.encodedData,
    required this.generatedAt,
    required this.createdAt,
    this.updatedAt,
    required this.scanCount,
    this.lastScannedAt,
    required this.version,
  });

  QrCode copyWith({
    int? id,
    int? studentId,
    String? studentName,
    String? studentCode,
    int? studentLevel,
    String? studentDepartment,
    String? qrData,
    String? encodedData,
    DateTime? generatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? scanCount,
    DateTime? lastScannedAt,
    int? version,
  }) {
    return QrCode(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentCode: studentCode ?? this.studentCode,
      studentLevel: studentLevel ?? this.studentLevel,
      studentDepartment: studentDepartment ?? this.studentDepartment,
      qrData: qrData ?? this.qrData,
      encodedData: encodedData ?? this.encodedData,
      generatedAt: generatedAt ?? this.generatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scanCount: scanCount ?? this.scanCount,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrCode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          studentId == other.studentId &&
          studentName == other.studentName &&
          studentCode == other.studentCode &&
          studentLevel == other.studentLevel &&
          studentDepartment == other.studentDepartment &&
          qrData == other.qrData &&
          encodedData == other.encodedData &&
          generatedAt == other.generatedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          scanCount == other.scanCount &&
          lastScannedAt == other.lastScannedAt &&
          version == other.version;

  @override
  int get hashCode => Object.hashAll([
        id,
        studentId,
        studentName,
        studentCode,
        studentLevel,
        studentDepartment,
        qrData,
        encodedData,
        generatedAt,
        createdAt,
        updatedAt,
        scanCount,
        lastScannedAt,
        version,
      ]);

  @override
  String toString() =>
      'QrCode(studentId: $studentId, code: $studentCode, scans: $scanCount)';

  factory QrCode.fromJson(Map<String, dynamic> json) {
    return QrCode(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      studentCode: json['student_code'] ?? '',
      studentLevel: json['student_level'] ?? 1,
      studentDepartment: json['student_department'] ?? 'General',
      qrData: json['qr_data']?['raw'] ?? '',
      encodedData: json['qr_data']?['encoded'] ?? '',
      generatedAt: DateTime.parse(json['generated_at'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      scanCount: json['scan_count'] ?? 0,
      lastScannedAt: json['last_scanned_at'] != null ? DateTime.parse(json['last_scanned_at']) : null,
      version: json['version'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'student_code': studentCode,
      'student_level': studentLevel,
      'student_department': studentDepartment,
      'qr_data': {'raw': qrData, 'encoded': encodedData},
      'generated_at': generatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'scan_count': scanCount,
      'last_scanned_at': lastScannedAt?.toIso8601String(),
      'version': version,
    };
  }

  bool get isExpired => DateTime.now().difference(generatedAt).inDays > 30;
  String get shortCode => studentCode.length > 8 ? '${studentCode.substring(0, 8)}...' : studentCode;
}
