import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/models/spare_part_model.dart';

void main() {
  group('SparePartModel', () {
    test('parses a spare part document', () {
      final part = SparePartModel.fromJson('tap_washer', {
        'name': 'Tap washer 15mm',
        'categoryId': 'plumbing',
        'description': 'Rubber tap washers',
        'unit': 'pack',
        'price': 49,
        'isActive': true,
        'sortOrder': 3,
      });

      expect(part.id, 'tap_washer');
      expect(part.name, 'Tap washer 15mm');
      expect(part.categoryId, 'plumbing');
      expect(part.description, 'Rubber tap washers');
      expect(part.unit, 'pack');
      expect(part.price, 49);
      expect(part.isActive, isTrue);
      expect(part.sortOrder, 3);
    });

    test('falls back to defaults', () {
      final part = SparePartModel.fromJson('x', {});

      expect(part.name, '');
      expect(part.categoryId, '');
      expect(part.description, '');
      expect(part.unit, 'piece');
      expect(part.price, 0);
      expect(part.isActive, isTrue);
      expect(part.sortOrder, 0);
    });
  });

  group('SpareOrderModel', () {
    final now = DateTime.utc(2026, 8, 8, 16);

    test('parses an order document', () {
      final order = SpareOrderModel.fromJson('ord-1', {
        'technicianId': 'tech-1',
        'partId': 'tap_washer',
        'partName': 'Tap washer 15mm',
        'quantity': 3,
        'amount': 147,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),
      });

      expect(order.id, 'ord-1');
      expect(order.technicianId, 'tech-1');
      expect(order.partId, 'tap_washer');
      expect(order.partName, 'Tap washer 15mm');
      expect(order.quantity, 3);
      expect(order.amount, 147);
      expect(order.status, SpareOrderModel.pending);
      expect(order.createdAt, now.toLocal());
    });

    test('falls back to pending status', () {
      final order = SpareOrderModel.fromJson('ord-2', {});

      expect(order.technicianId, '');
      expect(order.quantity, 0);
      expect(order.amount, 0);
      expect(order.status, SpareOrderModel.pending);
    });
  });
}
