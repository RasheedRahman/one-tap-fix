import 'package:cloud_firestore/cloud_firestore.dart';

/// The `users/{uid}` document — the single profile record for every
/// authenticated person (customer, technician, admin).
/// Role is immutable after creation; enforced by Firestore rules too.
class UserModel {
  const UserModel({
    required this.uid,
    required this.role,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    this.locale = 'en',
    this.languages = const ['en'],
    this.isBlocked = false,
    this.isOnline = false,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String role;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String locale;
  final List<String> languages;
  final bool isBlocked;
  final bool isOnline;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserModel.fromJson(String uid, Map<String, dynamic> json) {
    return UserModel(
      uid: uid,
      role: json['role'] as String? ?? 'customer',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      locale: json['locale'] as String? ?? 'en',
      languages: (json['languages'] as List?)?.cast<String>() ?? const ['en'],
      isBlocked: json['isBlocked'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
