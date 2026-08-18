import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer's rating + review for a completed job.
/// Document id = the booking id → at most one review per booking
/// (enforced by rules via `!exists(...)` on create).
class ReviewModel {
  const ReviewModel({
    required this.bookingId,
    required this.customerId,
    required this.technicianId,
    required this.rating,
    required this.createdAt,
    this.reviewText = '',
    this.photos = const [],
    this.customerName,
  });

  final String bookingId;
  final String customerId;
  final String technicianId;

  /// 1–5 stars.
  final int rating;
  final String reviewText;
  final List<String> photos;
  final DateTime createdAt;

  /// Denormalized at write time for fast list rendering.
  final String? customerName;

  factory ReviewModel.fromJson(String id, Map<String, dynamic> json) {
    return ReviewModel(
      bookingId: json['bookingId'] as String? ?? id,
      customerId: json['customerId'] as String? ?? '',
      technicianId: json['technicianId'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      reviewText: json['reviewText'] as String? ?? '',
      photos: (json['photos'] as List?)?.cast<String>() ?? const [],
      customerName: json['customerName'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toDocument() => {
        'bookingId': bookingId,
        'customerId': customerId,
        'technicianId': technicianId,
        'rating': rating,
        'reviewText': reviewText,
        'photos': photos,
        'customerName': customerName,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
