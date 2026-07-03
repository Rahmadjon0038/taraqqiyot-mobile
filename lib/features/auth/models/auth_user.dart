import 'dart:convert';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.username,
    required this.role,
    required this.raw,
  });

  final int id;
  final String name;
  final String surname;
  final String username;
  final String role;
  final Map<String, dynamic> raw;

  String get fullName =>
      [name, surname].where((part) => part.trim().isNotEmpty).join(' ');
  String get avatarKey => _asString(raw['avatar_key']);
  String get avatarUrl => _asString(raw['avatar_url']);
  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      surname: _asString(json['surname']),
      username: _asString(json['username']),
      role: _asString(json['role']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => raw;

  AuthUser copyWith({
    int? id,
    String? name,
    String? surname,
    String? username,
    String? role,
    Map<String, dynamic>? raw,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      username: username ?? this.username,
      role: role ?? this.role,
      raw: raw ?? this.raw,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  static String _asString(Object? value) => value?.toString() ?? '';

  String toEncodedJson() => jsonEncode(raw);
}
