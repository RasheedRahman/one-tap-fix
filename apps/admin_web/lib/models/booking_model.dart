import 'package:cloud_firestore/cloud_firestore.dart';

/// Bookings list model for the admin panel (plan §4.2).
class BookingModel {
  const BookingModel({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.categoryName,
    required this.status,
    required this.createdAt,
    this.technicianId,
    this.technicianName = '',
    this.amount = 0,
    this.paymentStatus = '',
    this.complaintStatus = '',
    this.complaintReason = '',
  });

  final String id;
  final String bookingId;
  final String customerId;
  final String? technicianId;
  final String technicianName;
  final String categoryName;
  final String status;
  final DateTime createdAt;
  final int amount;
  final String paymentStatus;
  final String complaintStatus;
  final String complaintReason;

  factory BookingModel.fromJson(String id, Map<String, dynamic> json) {
    final pricing = (json['pricing'] as Map?)?.cast<String, dynamic>();
    final minCharge = (pricing?['minCharge'] as num?)?.toInt() ?? 0;
    final serviceCharge = (pricing?['serviceCharge'] as num?)?.toInt() ?? 0;
    final gstPercent = (pricing?['gstPercent'] as num?)?.toInt() ?? 0;
    final amount =
        minCharge +
        serviceCharge +
        ((minCharge + serviceCharge) * gstPercent / 100).round();
    final payment = (json['payment'] as Map?)?.cast<String, dynamic>();
    final complaint = (json['complaint'] as Map?)?.cast<String, dynamic>();

    return BookingModel(
      id: id,
      bookingId: json['bookingId'] as String? ?? id,
      customerId: json['customerId'] as String? ?? '',
      technicianId: json['technicianId'] as String?,
      technicianName:
          ((json['technicianInfo'] as Map?)?.cast<String, dynamic>()['name']
              as String?) ??
          '—',
      categoryName: json['categoryName'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: amount,
      paymentStatus: payment?['status'] as String? ?? '',
      complaintStatus: complaint?['status'] as String? ?? '',
      complaintReason: complaint?['reason'] as String? ?? '',
    );
  }
}
