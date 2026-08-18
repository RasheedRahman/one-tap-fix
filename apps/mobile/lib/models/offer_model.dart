import 'package:cloud_firestore/cloud_firestore.dart';

/// The `offers/{id}` document — promotions shown on the home screen.
class OfferModel {
  const OfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.validFrom,
    required this.validTo,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String description;
  final int discountPercent;
  final String? imageUrl;
  final DateTime validFrom;
  final DateTime validTo;
  final bool isActive;

  bool get isCurrentlyValid {
    final now = DateTime.now();
    return isActive && now.isAfter(validFrom) && now.isBefore(validTo);
  }

  factory OfferModel.fromJson(String id, Map<String, dynamic> json) {
    return OfferModel(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      validFrom: (json['validFrom'] as Timestamp?)?.toDate() ?? DateTime(2000),
      validTo: (json['validTo'] as Timestamp?)?.toDate() ?? DateTime(2100),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
