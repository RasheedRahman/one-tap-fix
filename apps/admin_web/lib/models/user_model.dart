import 'package:cloud_firestore/cloud_firestore.dart';

/// The `users/{uid}` document — same schema as the mobile app.
/// The admin panel only needs role + name + block state.
class UserModel {
  const UserModel({
    required this.uid,
    required this.role,
    required this.name,
    this.phone,
    this.email,
    this.isBlocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String role;
  final String name;
  final String? phone;
  final String? email;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserModel.fromJson(String uid, Map<String, dynamic> json) {
    return UserModel(
      uid: uid,
      role: json['role'] as String? ?? 'customer',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      isBlocked: json['isBlocked'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
