/// Technician profile for the admin panel (plan §4.1/§4.3).
class TechnicianModel {
  const TechnicianModel({
    required this.uid,
    required this.skills,
    required this.experienceYears,
    required this.rating,
    required this.ratingsCount,
    required this.completedJobs,
    required this.cancelledJobs,
    required this.kycStatus,
    required this.isAvailable,
    required this.balance,
    this.name = '',
    this.phone = '',
    this.subscription,
    this.skillTest,
  });

  final String uid;
  final String name;
  final String phone;
  final List<String> skills;
  final int experienceYears;
  final double rating;
  final int ratingsCount;
  final int completedJobs;
  final int cancelledJobs;
  final String kycStatus;
  final bool isAvailable;
  final int balance;
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic>? skillTest;

  /// Active plan label (e.g. "monthly · 10%") or '' if none.
  String get subscriptionLabel {
    final s = subscription;
    if (s == null || s['status'] != 'active') return '';
    return '${s['plan']} · ${s['commissionPercent']}%';
  }

  double get completionRate => completedJobs + cancelledJobs == 0
      ? 0
      : completedJobs / (completedJobs + cancelledJobs) * 100;

  factory TechnicianModel.fromJson(String uid, Map<String, dynamic> json) {
    return TechnicianModel(
      uid: uid,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      skills: (json['skills'] as List?)?.cast<String>() ?? const [],
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingsCount: (json['ratingsCount'] as num?)?.toInt() ?? 0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      cancelledJobs: (json['cancelledJobs'] as num?)?.toInt() ?? 0,
      kycStatus: json['kycStatus'] as String? ?? 'pending',
      isAvailable: json['isAvailable'] as bool? ?? false,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      subscription: json['subscription'] as Map<String, dynamic>?,
      skillTest: json['skillTest'] as Map<String, dynamic>?,
    );
  }
}
