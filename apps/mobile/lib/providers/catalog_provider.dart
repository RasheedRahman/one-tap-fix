import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/offer_model.dart';
import '../models/service_model.dart';

/// Loads the service catalog (categories) and promotions for the home
/// screen. Both collections are admin-managed; this is read-only.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  List<ServiceModel>? _services;
  List<OfferModel>? _offers;
  bool _loading = false;
  String? _error;

  List<ServiceModel>? get services => _services;
  List<OfferModel>? get offers => _offers;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    if (_loading || _services != null) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final servicesFuture = _db
          .collection('services')
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();
      final offersFuture = _db.collection('offers').get();

      final results = await Future.wait([servicesFuture, offersFuture]);
      final servicesSnap = results[0];
      final offersSnap = results[1];

      _services = servicesSnap.docs
          .map((d) => ServiceModel.fromJson(d.id, d.data()))
          .toList();
      _offers = offersSnap.docs
          .map((d) => OfferModel.fromJson(d.id, d.data()))
          .where((o) => o.isCurrentlyValid)
          .toList()
        ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    } catch (_) {
      _services = null;
      _offers = null;
      _error = 'Could not load services. Check your connection.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    _loading = false;
    await load();
  }

  ServiceModel? byId(String id) {
    final services = _services;
    if (services == null) return null;
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }
}
