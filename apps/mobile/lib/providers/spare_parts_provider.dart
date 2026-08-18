import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/spare_part_model.dart';

/// Spare parts marketplace (plan §5): technicians browse the admin-
/// managed catalog and place orders; admins fulfill them.
class SparePartsProvider extends ChangeNotifier {
  SparePartsProvider({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String get _uid => _auth.currentUser?.uid ?? '';

  Stream<List<SparePartModel>> streamActiveParts() {
    return _db
        .collection('spare_parts')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SparePartModel.fromJson(d.id, d.data()))
            .toList());
  }

  Stream<List<SpareOrderModel>> streamMyOrders() {
    return _db
        .collection('spare_orders')
        .where('technicianId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SpareOrderModel.fromJson(d.id, d.data()))
            .toList());
  }

  /// Returns null on success, else a user-friendly error message.
  Future<String?> placeOrder({
    required SparePartModel part,
    required int quantity,
  }) async {
    if (_uid.isEmpty) return 'Not signed in.';
    if (quantity < 1) return 'Quantity must be at least 1.';
    try {
      await _db.collection('spare_orders').add({
        'technicianId': _uid,
        'partId': part.id,
        'partName': part.name,
        'quantity': quantity,
        'amount': part.price * quantity,
        'status': SpareOrderModel.pending,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not place the order.';
    } catch (_) {
      return 'Could not place the order.';
    }
  }

  /// Technicians may cancel their own order while it is pending.
  Future<String?> cancelOrder(String orderId) async {
    try {
      await _db.collection('spare_orders').doc(orderId).update({
        'status': SpareOrderModel.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not cancel the order.';
    } catch (_) {
      return 'Could not cancel the order.';
    }
  }
}
