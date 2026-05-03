// lib/models/doctor.dart
// ✅ Fix: شيلنا password — مش المفروض الـ app يخزن passwords
class Doctor {
  final int id;
  final String name;
  final String username;
  final String? email;

  Doctor({
    required this.id,
    required this.name,
    required this.username,
    this.email,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
    };
  }
}
