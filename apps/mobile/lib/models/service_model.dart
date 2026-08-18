import 'package:flutter/material.dart';

/// The `services/{id}` document — admin-managed service categories.
/// Pricing is shown to customers before booking (transparent pricing).
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.minCharge,
    required this.serviceCharge,
    required this.gstPercent,
    this.nameLocalized = const {},
    this.sparePartsPriceList = const {},
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
    this.tags = const [],
  });

  final String id;
  final String name;

  /// Localized names (ta/kn/hi/en) — filled by the multi-language feature.
  final Map<String, String> nameLocalized;

  /// Key into [ServiceIcons.lookup]; keeps the Firestore doc icon-agnostic.
  final String iconKey;
  final int minCharge;
  final int serviceCharge;
  final Map<String, int> sparePartsPriceList;
  final int gstPercent;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final List<String> tags;

  bool get isEmergencyCapable => tags.contains('emergency');

  /// Estimated total = (min + service) with GST, rounded to whole rupees.
  int get estimatedTotal {
    final base = minCharge + serviceCharge;
    final gst = (base * gstPercent / 100).round();
    return base + gst;
  }

  factory ServiceModel.fromJson(String id, Map<String, dynamic> json) {
    return ServiceModel(
      id: id,
      name: json['name'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'misc',
      minCharge: (json['minCharge'] as num?)?.toInt() ?? 0,
      serviceCharge: (json['serviceCharge'] as num?)?.toInt() ?? 0,
      sparePartsPriceList: Map<String, int>.from(
        (json['sparePartsPriceList'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            const {},
      ),
      gstPercent: (json['gstPercent'] as num?)?.toInt() ?? 18,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// Material icon lookup keyed by the `iconKey` field of a service.
/// Adding a new category requires a matching icon key here (and in the
/// admin panel later).
abstract final class ServiceIcons {
  static const Map<String, IconData> lookup = {
    'electrical': Icons.lightbulb_rounded,
    'plumbing': Icons.plumbing_rounded,
    'ac_repair': Icons.ac_unit_rounded,
    'civil_work': Icons.house_siding_rounded,
    'carpenter': Icons.handyman_rounded,
    'cleaning': Icons.cleaning_services_rounded,
    'painting': Icons.format_paint_rounded,
    'cctv_installation': Icons.videocam_rounded,
    'ro_geyser_solar': Icons.water_drop_rounded,
    'misc': Icons.miscellaneous_services_rounded,
  };

  static IconData forKey(String key) => lookup[key] ?? lookup['misc']!;
}
