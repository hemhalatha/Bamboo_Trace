import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'],
      email: data['email'] ?? '',
      role: data['role'] ?? 'customer',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
