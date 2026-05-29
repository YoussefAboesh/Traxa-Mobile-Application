class Doctor {
  final int id;
  final String name;
  final String username;
  final String? email;

  const Doctor({
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
      };

  Doctor copyWith({int? id, String? name, String? username, String? email}) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Doctor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          username == other.username &&
          email == other.email;

  @override
  int get hashCode => Object.hash(id, name, username, email);

  @override
  String toString() => 'Doctor(id: $id, username: $username, name: $name)';
}
