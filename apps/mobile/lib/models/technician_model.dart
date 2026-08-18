import 'package:cloud_firestore/cloud_firestore.dart';

/// Live technician location snapshot.
class TechnicianLocation {
  const TechnicianLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'geopoint': GeoPoint(latitude, longitude),
    'updatedAt': updatedAt,
  };

  factory TechnicianLocation.fromJson(Map<String, dynamic> json) {
    final geopoint = json['geopoint'] as GeoPoint?;
    return TechnicianLocation(
      latitude: geopoint?.latitude ?? (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: geopoint?.longitude ?? (json['lng'] as num?)?.toDouble() ?? 0,
      updatedAt: switch (json['updatedAt']) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        _ => DateTime.now(),
      },
    );
  }
}

/// The `technicians/{uid}` document — technician-only profile used by
/// the matching engine (skills, availability, live location, stats) and
/// the earnings dashboard (plan §3.6).
class TechnicianModel {
  const TechnicianModel({
    required this.uid,
    required this.skills,
    required this.experienceYears,
    required this.rating,
    required this.ratingsCount,
    required this.completedJobs,
    required this.cancelledJobs,
    required this.isAvailable,
    required this.kycStatus,
    required this.createdAt,
    required this.updatedAt,
    this.currentLocation,
    this.totalEarned = 0,
    this.balance = 0,
    this.earningsByMonth = const {},
    this.subscription,
    this.skillTest,
  });

  final String uid;
  final List<String> skills;
  final int experienceYears;
  final double rating;
  final int ratingsCount;
  final int completedJobs;
  final int cancelledJobs;
  final bool isAvailable;
  final String kycStatus;
  final TechnicianLocation? currentLocation;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Lifetime earnings maintained by the `confirmPayment` callable.
  final int totalEarned;

  /// Withdrawable balance (payouts arrive with the admin panel).
  final int balance;

  /// `{ "YYYY-MM": amount }` — summed per payment confirmation.
  final Map<String, dynamic> earningsByMonth;

  /// `{plan, status, expiry}` from the future subscription feature.
  final Map<String, dynamic>? subscription;

  /// `{status, score, total}` from the skill-based test.
  final Map<String, dynamic>? skillTest;

  bool get isKycApproved => kycStatus == 'approved';

  int earningsIn(String month) =>
      (earningsByMonth[month] as num?)?.toInt() ?? 0;

  bool get hasActiveSubscription => subscription?['status'] == 'active';

  factory TechnicianModel.fromJson(String uid, Map<String, dynamic> json) {
    return TechnicianModel(
      uid: uid,
      skills: (json['skills'] as List?)?.cast<String>() ?? const [],
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingsCount: (json['ratingsCount'] as num?)?.toInt() ?? 0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      cancelledJobs: (json['cancelledJobs'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? false,
      kycStatus: json['kycStatus'] as String? ?? 'pending',
      currentLocation: json['currentLocation'] is Map
          ? TechnicianLocation.fromJson(
              (json['currentLocation'] as Map).cast<String, dynamic>(),
            )
          : null,
      totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      earningsByMonth:
          (json['earningsByMonth'] as Map?)?.cast<String, dynamic>() ??
          const {},
      subscription: (json['subscription'] as Map?)?.cast<String, dynamic>(),
      skillTest: (json['skillTest'] as Map?)?.cast<String, dynamic>(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
