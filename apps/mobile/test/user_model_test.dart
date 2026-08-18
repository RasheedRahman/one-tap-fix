import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    final now = DateTime.utc(2026, 8, 8, 12);

    test('parses a complete document', () {
      final model = UserModel.fromJson('uid-1', {
        'role': 'technician',
        'name': 'Ravi Kumar',
        'phone': '+919876543210',
        'email': 'ravi@example.com',
        'photoUrl': 'https://example.com/p.jpg',
        'locale': 'en',
        'languages': ['en', 'ta'],
        'isBlocked': false,
        'isOnline': true,
        'onboardingCompleted': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(model.uid, 'uid-1');
      expect(model.role, 'technician');
      expect(model.name, 'Ravi Kumar');
      expect(model.phone, '+919876543210');
      expect(model.languages, ['en', 'ta']);
      expect(model.onboardingCompleted, isTrue);
      expect(model.isOnline, isTrue);
      expect(model.createdAt.isAtSameMomentAs(now), isTrue);
    });

    test('applies safe defaults for missing fields', () {
      final model = UserModel.fromJson('uid-2', {
        'role': 'customer',
        'name': 'Priya',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(model.phone, isNull);
      expect(model.photoUrl, isNull);
      expect(model.locale, 'en');
      expect(model.languages, ['en']);
      expect(model.isBlocked, isFalse);
      expect(model.isOnline, isFalse);
      expect(model.onboardingCompleted, isFalse);
    });
  });
}
