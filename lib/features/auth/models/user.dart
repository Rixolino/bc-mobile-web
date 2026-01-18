class User {
  final int? id;
  final String email;
  final String password;
  final DateTime? createdAt;
  final String? nickname;

  User({
    this.id,
    required this.email,
    required this.password,
    this.createdAt,
    this.nickname,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      email: json['email'] as String,
      password: json['password'] as String,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      nickname: json['nickname'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'created_at': createdAt?.toIso8601String(),
      'nickname': nickname,
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? password,
    DateTime? createdAt,
    String? nickname,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      nickname: nickname ?? this.nickname,
    );
  }
}