// lib/models/qr_code.dart
// ignore_for_file: file_names

class QRcode {
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

  QRcode({
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

  factory QRcode.fromJson(Map<String, dynamic> json) {
    return QRcode(
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
      'qr_data': {
        'raw': qrData,
        'encoded': encodedData,
      },
      'generated_at': generatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'scan_count': scanCount,
      'last_scanned_at': lastScannedAt?.toIso8601String(),
      'version': version,
    };
  }

  // Getters مفيدة
  bool get isExpired => DateTime.now().difference(generatedAt).inDays > 30;
  String get shortCode => studentCode.length > 8 ? '${studentCode.substring(0, 8)}...' : studentCode;
}