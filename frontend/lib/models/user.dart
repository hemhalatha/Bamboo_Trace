class UserModel {
  final String? id;
  final String? name;
  final String email;
  final String role;
  final DateTime? createdAt;

  UserModel({
    this.id,
    this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'],
      name: data['name'],
      email: data['email'] ?? '',
      role: data['role'] ?? 'customer',
      createdAt: DateTime.tryParse(data['createdAt'] ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
    };
  }
}
