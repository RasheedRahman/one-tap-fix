import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_admin/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    final now = DateTime.utc(2026, 8, 8, 12);

    test('parses an admin document', () {
      final model = UserModel.fromJson('uid-admin', {
        'role': 'admin',
        'name': 'Admin One',
        'email': 'admin@mepconnect.in',
        'isBlocked': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(model.uid, 'uid-admin');
      expect(model.role, 'admin');
      expect(model.name, 'Admin One');
      expect(model.phone, isNull);
    });

    test('applies safe defaults for missing fields', () {
      final model = UserModel.fromJson('uid-x', {
        'name': 'X',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(model.role, 'customer');
      expect(model.isBlocked, isFalse);
    });
  });
}
