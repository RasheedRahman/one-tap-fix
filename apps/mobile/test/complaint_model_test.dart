import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/models/complaint_model.dart';

void main() {
  group('ComplaintModel', () {
    final now = DateTime.utc(2026, 8, 8, 16);

    test('parses a complaint document', () {
      final complaint = ComplaintModel.fromJson('book-1', {
        'bookingId': 'book-1',
        'customerId': 'cust-1',
        'technicianId': 'tech-1',
        'reason': 'job_not_done_properly',
        'description': 'Leak still there',
        'photoUrls': ['https://x.com/photo.jpg'],
        'status': 'submitted',
        'createdAt': Timestamp.fromDate(now),
      });

      expect(complaint.bookingId, 'book-1');
      expect(complaint.technicianId, 'tech-1');
      expect(complaint.reason, ComplaintReasons.jobNotDoneProperly);
      expect(complaint.description, 'Leak still there');
      expect(complaint.photoUrls, ['https://x.com/photo.jpg']);
      expect(complaint.status, 'submitted');
      expect(complaint.isResolved, isFalse);
      expect(complaint.createdAt, now.toLocal());
    });

    test('falls back to document id and defaults', () {
      final complaint = ComplaintModel.fromJson('book-2', {});

      expect(complaint.bookingId, 'book-2');
      expect(complaint.customerId, '');
      expect(complaint.reason, ComplaintReasons.other);
      expect(complaint.description, '');
      expect(complaint.photoUrls, isEmpty);
      expect(complaint.status, 'submitted');
    });

    test('auto-refund reasons mirror the server', () {
      expect(
        ComplaintReasons.autoRefund,
        contains(ComplaintReasons.jobNotDoneProperly),
      );
      expect(ComplaintReasons.label('overcharging'), 'Overcharged');
    });
  });
}
