import 'package:cloud_firestore/cloud_firestore.dart';

/// Complaint record for the admin panel (plan §4.2).
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
    this.resolution,
  });

  final String bookingId;
  final String customerId;
  final String? technicianId;
  final String reason;
  final String description;
  final List<String> photoUrls;
  final String status;
  final DateTime createdAt;
  final String? resolution;

  static String reasonLabel(String reason) => switch (reason) {
    'job_not_done_properly' => 'Job not done properly',
    'technician_no_show' => 'Technician did not show up',
    'overcharging' => 'Overcharged',
    'poor_behaviour' => 'Poor behaviour',
    _ => 'Other',
  };

  factory ComplaintModel.fromJson(String id, Map<String, dynamic> json) {
    return ComplaintModel(
      bookingId: json['bookingId'] as String? ?? id,
      customerId: json['customerId'] as String? ?? '',
      technicianId: json['technicianId'] as String?,
      reason: json['reason'] as String? ?? 'other',
      description: json['description'] as String? ?? '',
      photoUrls: (json['photoUrls'] as List?)?.cast<String>() ?? const [],
      status: json['status'] as String? ?? 'submitted',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolution: json['resolution'] as String?,
    );
  }
}
