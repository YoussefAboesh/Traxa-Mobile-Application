// lib/models/doctor.dart
class Doctor {
  final int id;
  final String name;
  final String username;
  final String? password;
  final String? email;

  Doctor({
    required this.id,
    required this.name,
    required this.username,
    this.password,
    this.email,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      password: json['password'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password': password,
      'email': email,
    };
  }
}