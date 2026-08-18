import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment/payout record for the admin panel (plan §4.4).
class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.customerId,
    this.technicianId,
    this.method = '',
    this.paidAt,
  });

  final String id;
  final String type;
  final int amount;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String method;
  final String? customerId;
  final String? technicianId;

  factory PaymentModel.fromJson(String id, Map<String, dynamic> json) {
    return PaymentModel(
      id: id,
      type: json['type'] as String? ?? 'payment',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'initiated',
      method: json['method'] as String? ?? '',
      customerId: json['customerId'] as String?,
      technicianId: json['technicianId'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (json['paidAt'] as Timestamp?)?.toDate(),
    );
  }
}
