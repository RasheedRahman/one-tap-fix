import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/models/booking_model.dart';
import 'package:mep_connect_mobile/models/service_model.dart';

void main() {
  group('ServiceModel', () {
    test('parses a document and computes pricing', () {
      final service = ServiceModel.fromJson('plumbing', {
        'name': 'Plumbing',
        'iconKey': 'plumbing',
        'minCharge': 199,
        'serviceCharge': 299,
        'gstPercent': 18,
        'sortOrder': 2,
        'tags': ['emergency'],
      });

      expect(service.name, 'Plumbing');
      expect(service.isEmergencyCapable, isTrue);
      expect(service.estimatedTotal, 588); // (199+299) + 18% of 498
      expect(ServiceIcons.forKey('plumbing'), Icons.plumbing_rounded);
      expect(
        ServiceIcons.forKey('unknown_key'),
        Icons.miscellaneous_services_rounded,
      );
    });

    test('applies safe defaults', () {
      final service = ServiceModel.fromJson('x', {'name': 'X'});
      expect(service.minCharge, 0);
      expect(service.gstPercent, 18);
      expect(service.isActive, isTrue);
      expect(service.tags, isEmpty);
    });
  });

  group('BookingModel', () {
    final now = DateTime.utc(2026, 8, 8, 12);

    test('parses a booking document', () {
      final booking = BookingModel.fromJson('doc-1', {
        'bookingId': 'MEP-ABC123',
        'customerId': 'cust-1',
        'categoryId': 'plumbing',
        'categoryName': 'Plumbing',
        'description': 'Leaking tap',
        'mediaUrls': ['https://x.com/a.jpg'],
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'pending',
        'location': {
          'lat': 12.97,
          'lng': 77.59,
          'address': 'Indiranagar, Bengaluru',
          'geopoint': GeoPoint(12.97, 77.59),
          'capturedAt': Timestamp.fromDate(now),
        },
        'pricing': {'minCharge': 199, 'serviceCharge': 299, 'gstPercent': 18},
        'isEmergency': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(booking.bookingId, 'MEP-ABC123');
      expect(booking.status, BookingStatus.pending);
      expect(booking.canCancelByCustomer, isTrue);
      expect(booking.location.address, 'Indiranagar, Bengaluru');
      expect(booking.pricing.estimatedTotal, 588);
      expect(booking.mediaUrls, ['https://x.com/a.jpg']);
    });

    test('parses an in-flight booking with technician snapshot', () {
      final booking = BookingModel.fromJson('doc-3', {
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'en_route',
        'technicianId': 'tech-1',
        'etaMinutes': 12,
        'technicianInfo': {'name': 'Ravi', 'phone': '+91', 'rating': 4.5},
        'enRouteAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(booking.technicianId, 'tech-1');
      expect(booking.technicianName, 'Ravi');
      expect(booking.etaMinutes, 12);
      expect(booking.enRouteAt, now.toLocal());
      expect(booking.nextTechnicianAction, JobActions.startService);
      expect(booking.canCancelByClient, isFalse);
      expect(booking.canCancelAssignedByCustomer, isTrue);
      expect(BookingStatus.isActiveForTechnician(booking.status), isTrue);
    });

    test('cancelled bookings are not cancellable', () {
      final booking = BookingModel.fromJson('doc-2', {
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'cancelled',
        'cancelledAt': Timestamp.fromDate(now),
        'cancellationReason': 'cancelled_by_customer',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(booking.canCancelByCustomer, isFalse);
      expect(booking.cancellationReason, 'cancelled_by_customer');
      expect(booking.nextTechnicianAction, isNull);
      expect(BookingStatus.label('matching'), 'Finding technician');
    });

    test('completed bookings produce a stable invoice number', () {
      final booking = BookingModel.fromJson('doc-4', {
        'bookingId': 'MEP-ABC123',
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'completed',
        'completedAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(booking.invoiceNumber, 'INV-MEP-ABC123');
      expect(booking.isHistory, isTrue);
      expect(booking.invoiceDate, now.toLocal());
    });

    test('in-flight bookings are not part of service history', () {
      final booking = BookingModel.fromJson('doc-5', {
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'in_progress',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(booking.isHistory, isFalse);
      expect(booking.invoiceDate, now.toLocal());
      expect(booking.nextTechnicianAction, JobActions.complete);
    });

    test('parses the payment map and payment-state helpers', () {
      final paid = BookingModel.fromJson('doc-6', {
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'completed',
        'payment': {
          'method': 'upi',
          'status': 'paid',
          'transactionId': 'TXN-ABC123',
          'paidAt': Timestamp.fromDate(now),
        },
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(paid.paymentStatus, 'paid');
      expect(paid.paymentMethod, 'upi');
      expect(paid.paidAt, now.toLocal());
      expect(paid.needsPayment, isFalse);

      final unpaid = BookingModel.fromJson('doc-7', {
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'completed',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(unpaid.paymentStatus, '');
      expect(unpaid.paidAt, isNull);
      expect(unpaid.needsPayment, isTrue);
    });

    test('complaint helpers gate filing on completed, complaint-free', () {
      final completed = BookingModel.fromJson('doc-8', {
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'completed',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(completed.canFileComplaint, isTrue);
      expect(completed.complaintStatus, '');

      final complained = BookingModel.fromJson('doc-9', {
        'customerId': 'cust-1',
        'categoryId': 'x',
        'categoryName': 'X',
        'scheduledAt': Timestamp.fromDate(now),
        'status': 'completed',
        'complaint': {'reason': 'job_not_done_properly', 'status': 'submitted'},
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(complained.canFileComplaint, isFalse);
      expect(complained.complaintStatus, 'submitted');
      expect(complained.complaintReason, 'job_not_done_properly');
    });
  });

  group('BookingLocation', () {
    test('round-trips through json', () {
      final location = BookingLocation(
        latitude: 12.9716,
        longitude: 77.5946,
        address: 'Bengaluru',
        capturedAt: DateTime.utc(2026, 8, 8),
      );
      final restored = BookingLocation.fromJson(location.toJson());
      expect(restored.latitude, 12.9716);
      expect(restored.longitude, 77.5946);
      expect(restored.address, 'Bengaluru');
      expect(restored.toJson()['geopoint'], isA<GeoPoint>());
    });
  });
}
