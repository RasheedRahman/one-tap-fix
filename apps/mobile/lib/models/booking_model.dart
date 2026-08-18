import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer-supplied location for a booking.
class BookingLocation {
  const BookingLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final String address;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'address': address,
    'geopoint': GeoPoint(latitude, longitude),
    'capturedAt': capturedAt,
  };

  factory BookingLocation.fromJson(Map<String, dynamic> json) {
    final geopoint = json['geopoint'] as GeoPoint?;
    final captured = json['capturedAt'];
    return BookingLocation(
      latitude: (json['lat'] as num?)?.toDouble() ?? geopoint?.latitude ?? 0,
      longitude: (json['lng'] as num?)?.toDouble() ?? geopoint?.longitude ?? 0,
      address: json['address'] as String? ?? '',
      capturedAt: switch (captured) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        _ => DateTime.now(),
      },
    );
  }
}

/// Pricing snapshot written at booking time (transparent + immutable).
class BookingPricing {
  const BookingPricing({
    required this.minCharge,
    required this.serviceCharge,
    required this.gstPercent,
  });

  final int minCharge;
  final int serviceCharge;
  final int gstPercent;

  int get baseTotal => minCharge + serviceCharge;
  int get gstAmount => (baseTotal * gstPercent / 100).round();
  int get estimatedTotal => baseTotal + gstAmount;

  Map<String, dynamic> toJson() => {
    'minCharge': minCharge,
    'serviceCharge': serviceCharge,
    'gstPercent': gstPercent,
  };

  factory BookingPricing.fromJson(Map<String, dynamic> json) {
    return BookingPricing(
      minCharge: (json['minCharge'] as num?)?.toInt() ?? 0,
      serviceCharge: (json['serviceCharge'] as num?)?.toInt() ?? 0,
      gstPercent: (json['gstPercent'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Lifecycle of a booking; mirrors the plan's flow.
abstract final class BookingStatus {
  static const String pending = 'pending';
  static const String matching = 'matching';
  static const String accepted = 'accepted';
  static const String enRoute = 'en_route';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String refunded = 'refunded';

  static const List<String> all = [
    pending,
    matching,
    accepted,
    enRoute,
    inProgress,
    completed,
    cancelled,
    refunded,
  ];

  static String label(String status) => switch (status) {
    pending => 'Pending',
    matching => 'Finding technician',
    accepted => 'Accepted',
    enRoute => 'Technician on the way',
    inProgress => 'In progress',
    completed => 'Completed',
    cancelled => 'Cancelled',
    refunded => 'Refunded',
    _ => status,
  };

  /// Statuses where a technician is actively involved (has the job).
  static bool isActiveForTechnician(String status) =>
      status == accepted || status == enRoute || status == inProgress;
}

/// Technician actions driving the on-site flow (Cloud Function callable).
abstract final class JobActions {
  static const String startTrip = 'start_trip';
  static const String startService = 'start_service';
  static const String complete = 'complete';
}

/// The `bookings/{id}` document — core entity of the marketplace.
class BookingModel {
  const BookingModel({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.scheduledAt,
    required this.status,
    required this.location,
    required this.pricing,
    required this.isEmergency,
    required this.createdAt,
    required this.updatedAt,
    this.technicianId,
    this.mediaUrls = const [],
    this.etaMinutes,
    this.technicianInfo,
    this.enRouteAt,
    this.startedServiceAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.payment,
    this.complaint,
  });

  final String id;
  final String bookingId;
  final String customerId;
  final String? technicianId;
  final String categoryId;
  final String categoryName;
  final String description;
  final List<String> mediaUrls;
  final DateTime scheduledAt;
  final String status;
  final BookingLocation location;
  final BookingPricing pricing;
  final bool isEmergency;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// ETA in minutes, snapshotted when the technician accepts.
  final int? etaMinutes;

  /// `{name, phone, rating}` snapshot of the assigned technician.
  final Map<String, dynamic>? technicianInfo;

  final DateTime? enRouteAt;
  final DateTime? startedServiceAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  /// `{method, status, transactionId, paidAt}` — written by the
  /// `confirmPayment` callable (plan §2.6).
  final Map<String, dynamic>? payment;

  /// `{reason, status}` — written by the `submitComplaint` callable
  /// (plan §2.8).
  final Map<String, dynamic>? complaint;

  String get complaintStatus => (complaint?['status'] as String?) ?? '';
  String get complaintReason => (complaint?['reason'] as String?) ?? '';

  /// A completed, complaint-free booking can be reported.
  bool get canFileComplaint =>
      status == BookingStatus.completed && complaintStatus.isEmpty;

  String get paymentStatus => (payment?['status'] as String?) ?? '';
  String get paymentMethod => (payment?['method'] as String?) ?? '';
  DateTime? get paidAt {
    final raw = payment?['paidAt'];
    return switch (raw) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => null,
    };
  }

  /// Payment is due while the job is underway or finished but unpaid.
  bool get needsPayment =>
      (status == BookingStatus.inProgress ||
          status == BookingStatus.completed) &&
      paymentStatus != 'paid';

  String get technicianName =>
      (technicianInfo?['name'] as String?) ?? 'Technician';

  /// Stable, human-readable invoice number for this booking
  /// (`INV-<short booking id>`, plan §5 service history).
  String get invoiceNumber => 'INV-${bookingId.toUpperCase()}';

  /// A booking that belongs in the customer's service history.
  bool get isHistory =>
      status == BookingStatus.completed ||
      status == BookingStatus.cancelled ||
      status == BookingStatus.refunded;

  /// The date shown on the invoice: completion, else booking creation.
  DateTime get invoiceDate => completedAt ?? createdAt;

  /// Customer may cancel self-service (client write) while waiting.
  bool get canCancelByClient =>
      status == BookingStatus.pending || status == BookingStatus.matching;

  /// Customer may ask the server to cancel an assigned job.
  bool get canCancelAssignedByCustomer =>
      status == BookingStatus.accepted || status == BookingStatus.enRoute;

  bool get canCancelByCustomer =>
      canCancelByClient || canCancelAssignedByCustomer;

  /// Technician action available for the current status, or null.
  String? get nextTechnicianAction => switch (status) {
    BookingStatus.accepted => JobActions.startTrip,
    BookingStatus.enRoute => JobActions.startService,
    BookingStatus.inProgress => JobActions.complete,
    _ => null,
  };

  factory BookingModel.fromJson(String id, Map<String, dynamic> json) {
    return BookingModel(
      id: id,
      bookingId: json['bookingId'] as String? ?? id,
      customerId: json['customerId'] as String? ?? '',
      technicianId: json['technicianId'] as String?,
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mediaUrls: (json['mediaUrls'] as List?)?.cast<String>() ?? const [],
      scheduledAt:
          (json['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] as String? ?? BookingStatus.pending,
      location: BookingLocation.fromJson(
        (json['location'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      pricing: BookingPricing.fromJson(
        (json['pricing'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      isEmergency: json['isEmergency'] as bool? ?? false,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      technicianInfo: (json['technicianInfo'] as Map?)?.cast<String, dynamic>(),
      enRouteAt: (json['enRouteAt'] as Timestamp?)?.toDate(),
      startedServiceAt: (json['startedServiceAt'] as Timestamp?)?.toDate(),
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (json['cancelledAt'] as Timestamp?)?.toDate(),
      cancellationReason: json['cancellationReason'] as String?,
      payment: (json['payment'] as Map?)?.cast<String, dynamic>(),
      complaint: (json['complaint'] as Map?)?.cast<String, dynamic>(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
