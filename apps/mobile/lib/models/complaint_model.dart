import 'package:cloud_firestore/cloud_firestore.dart';

/// Complaint reasons (plan §2.8).
abstract final class ComplaintReasons {
  static const String jobNotDoneProperly = 'job_not_done_properly';
  static const String technicianNoShow = 'technician_no_show';
  static const String overcharging = 'overcharging';
  static const String poorBehaviour = 'poor_behaviour';
  static const String other = 'other';

  static const List<String> all = [
    jobNotDoneProperly,
    technicianNoShow,
    overcharging,
    poorBehaviour,
    other,
  ];

  /// Reasons that auto-trigger a refund (mirrors Cloud Functions).
  static const List<String> autoRefund = [jobNotDoneProperly];

  static String label(String reason) => switch (reason) {
    jobNotDoneProperly => 'Job not done properly',
    technicianNoShow => 'Technician did not show up',
    overcharging => 'Overcharged',
    poorBehaviour => 'Poor behaviour',
    _ => 'Other',
  };
}

/// A customer's complaint about a completed job.
/// Document id = the booking id → at most one complaint per booking.
class ComplaintModel {
  const ComplaintModel({
    required this.bookingId,
    required this.customerId,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
    this.technicianId,
    this.photoUrls = const [],
  });

  final String bookingId;
  final String customerId;
  final String? technicianId;
  final String reason;
  final String description;
  final List<String> photoUrls;
  final String status;
  final DateTime createdAt;

  bool get isResolved => status == 'resolved';

  factory ComplaintModel.fromJson(String id, Map<String, dynamic> json) {
    return ComplaintModel(
      bookingId: json['bookingId'] as String? ?? id,
      customerId: json['customerId'] as String? ?? '',
      technicianId: json['technicianId'] as String?,
      reason: json['reason'] as String? ?? ComplaintReasons.other,
      description: json['description'] as String? ?? '',
      photoUrls: (json['photoUrls'] as List?)?.cast<String>() ?? const [],
      status: json['status'] as String? ?? 'submitted',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
