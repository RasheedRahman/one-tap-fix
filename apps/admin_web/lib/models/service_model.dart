/// Service category for the admin panel (plan §4.1 add/remove services).
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.minCharge,
    required this.serviceCharge,
    required this.gstPercent,
    required this.isActive,
    required this.sortOrder,
    required this.tags,
  });

  final String id;
  final String name;
  final String iconKey;
  final int minCharge;
  final int serviceCharge;
  final int gstPercent;
  final bool isActive;
  final int sortOrder;
  final List<String> tags;

  bool get isEmergencyCapable => tags.contains('emergency');

  factory ServiceModel.fromJson(String id, Map<String, dynamic> json) {
    return ServiceModel(
      id: id,
      name: json['name'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'miscellaneous',
      minCharge: (json['minCharge'] as num?)?.toInt() ?? 0,
      serviceCharge: (json['serviceCharge'] as num?)?.toInt() ?? 0,
      gstPercent: (json['gstPercent'] as num?)?.toInt() ?? 18,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'nameLocalized': {'en': name},
    'iconKey': iconKey,
    'minCharge': minCharge,
    'serviceCharge': serviceCharge,
    'gstPercent': gstPercent,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'tags': tags,
  };

  ServiceModel copyWith({
    String? name,
    String? iconKey,
    int? minCharge,
    int? serviceCharge,
    int? gstPercent,
    bool? isActive,
    int? sortOrder,
    List<String>? tags,
  }) {
    return ServiceModel(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      minCharge: minCharge ?? this.minCharge,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      gstPercent: gstPercent ?? this.gstPercent,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      tags: tags ?? this.tags,
    );
  }
}
