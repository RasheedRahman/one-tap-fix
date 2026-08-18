import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/models/review_model.dart';

void main() {
  group('ReviewModel', () {
    final now = DateTime.utc(2026, 8, 8, 14);

    test('parses a full review document', () {
      final review = ReviewModel.fromJson('book-1', {
        'bookingId': 'book-1',
        'customerId': 'cust-1',
        'technicianId': 'tech-1',
        'rating': 5,
        'reviewText': 'Great work',
        'photos': ['https://x.com/photo.jpg'],
        'customerName': 'Alice',
        'createdAt': Timestamp.fromDate(now),
      });

      expect(review.bookingId, 'book-1');
      expect(review.customerId, 'cust-1');
      expect(review.technicianId, 'tech-1');
      expect(review.rating, 5);
      expect(review.reviewText, 'Great work');
      expect(review.photos, ['https://x.com/photo.jpg']);
      expect(review.customerName, 'Alice');
      expect(review.createdAt, now.toLocal());
    });

    test('falls back to the document id for bookingId', () {
      final review = ReviewModel.fromJson('book-2', {'rating': 4});

      expect(review.bookingId, 'book-2');
      expect(review.rating, 4);
      expect(review.reviewText, '');
      expect(review.photos, isEmpty);
      expect(review.customerName, isNull);
    });

    test('toDocument carries a server-timestamp sentinel', () {
      final review = ReviewModel(
        bookingId: 'book-1',
        customerId: 'cust-1',
        technicianId: 'tech-1',
        rating: 5,
        createdAt: DateTime.now(),
      );

      final doc = review.toDocument();
      expect(doc['customerId'], 'cust-1');
      expect(doc['technicianId'], 'tech-1');
      expect(doc['rating'], 5);
      // Server-timestamp sentinel (rules require createdAt == request.time).
      expect(doc['createdAt'], isA<FieldValue>());
    });
  });
}
