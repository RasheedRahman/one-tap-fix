import 'package:cloud_firestore/cloud_firestore.dart';

/// Spare part in the marketplace catalog (plan §5).
class SparePartModel {
  const SparePartModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.isActive,
    required this.sortOrder,
    this.description = '',
    this.unit = 'piece',
  });

  final String id;
  final String name;
  final String categoryId;
  final String description;
  final String unit;
  final int price;
  final bool isActive;
  final int sortOrder;

  factory SparePartModel.fromJson(String id, Map<String, dynamic> json) {
    return SparePartModel(
      id: id,
      name: json['name'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String? ?? 'piece',
      price: (json['price'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'categoryId': categoryId,
    'description': description,
    'unit': unit,
    'price': price,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}

/// Technician spare parts order (plan §5).
class SpareOrderModel {
  const SpareOrderModel({
    required this.id,
    required this.technicianId,
    required this.partId,
    required this.partName,
    required this.quantity,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String technicianId;
  final String partId;
  final String partName;
  final int quantity;
  final int amount;
  final String status;
  final DateTime? createdAt;

  factory SpareOrderModel.fromJson(String id, Map<String, dynamic> json) {
    return SpareOrderModel(
      id: id,
      technicianId: json['technicianId'] as String? ?? '',
      partId: json['partId'] as String? ?? '',
      partName: json['partName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
