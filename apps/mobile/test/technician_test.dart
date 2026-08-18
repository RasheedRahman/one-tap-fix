import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/core/utils/geo.dart';
import 'package:mep_connect_mobile/models/technician_model.dart';

void main() {
  group('Geo', () {
    test('haversine distance Bengaluru → Chennai ~ 290 km', () {
      final km = Geo.haversineKm(12.9716, 77.5946, 13.0827, 80.2707);
      expect(km, closeTo(290, 15));
    });

    test('zero distance for identical points', () {
      expect(Geo.haversineKm(12.97, 77.59, 12.97, 77.59), 0);
    });

    test('ETA has a 10-minute floor', () {
      expect(Geo.etaMinutesForKm(0.5), 10);
      expect(Geo.etaMinutesForKm(15), 30);
    });
  });

  group('TechnicianModel', () {
    final now = DateTime.utc(2026, 8, 8, 12);

    test('parses a document with live location', () {
      final tech = TechnicianModel.fromJson('tech-1', {
        'skills': ['plumbing', 'electrical'],
        'experienceYears': 5,
        'rating': 4.5,
        'ratingsCount': 12,
        'completedJobs': 40,
        'cancelledJobs': 2,
        'isAvailable': true,
        'kycStatus': 'approved',
        'currentLocation': {
          'geopoint': GeoPoint(12.97, 77.59),
          'updatedAt': Timestamp.fromDate(now),
        },
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(tech.skills, ['plumbing', 'electrical']);
      expect(tech.isAvailable, isTrue);
      expect(tech.isKycApproved, isTrue);
      expect(tech.rating, 4.5);
      expect(tech.currentLocation!.latitude, 12.97);
      expect(tech.currentLocation!.longitude, 77.59);
    });

    test('applies safe defaults', () {
      final tech = TechnicianModel.fromJson('tech-2', {
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(tech.skills, isEmpty);
      expect(tech.isAvailable, isFalse);
      expect(tech.kycStatus, 'pending');
      expect(tech.isKycApproved, isFalse);
      expect(tech.currentLocation, isNull);
    });

    test('TechnicianLocation round-trips through json', () {
      final location = TechnicianLocation(
        latitude: 12.97,
        longitude: 77.59,
        updatedAt: now,
      );
      final restored = TechnicianLocation.fromJson(location.toJson());
      expect(restored.latitude, 12.97);
      expect(restored.longitude, 77.59);
      expect(restored.toJson()['geopoint'], isA<GeoPoint>());
    });

    test('parses earnings and subscription fields', () {
      final tech = TechnicianModel.fromJson('tech-3', {
        'totalEarned': 12400,
        'balance': 9900,
        'earningsByMonth': {'2026-08': 4200, '2026-07': 3800},
        'subscription': {'plan': 'pro', 'status': 'active'},
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      expect(tech.totalEarned, 12400);
      expect(tech.balance, 9900);
      expect(tech.earningsIn('2026-08'), 4200);
      expect(tech.earningsIn('2026-01'), 0);
      expect(tech.hasActiveSubscription, isTrue);
    });
  });
}
