import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Payments (plan §2.6): the server owns payment records via the
/// `initiatePayment` / `confirmPayment` callables — clients never write
/// to `payments/` or the booking's `payment` map directly.
class PaymentProvider extends ChangeNotifier {
  PaymentProvider({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const List<String> methods = ['upi', 'cash'];

  /// The payment record for a booking, or null before it is initiated.
  Stream<Map<String, dynamic>?> streamPayment(String bookingId) {
    return _db
        .collection('payments')
        .doc(bookingId)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  /// Returns null on success, else a user-friendly error message.
  Future<String?> initiatePayment({
    required String bookingId,
    required String method,
  }) async {
    if (!methods.contains(method)) return 'Invalid payment method.';
    return _call('initiatePayment', {
      'bookingId': bookingId,
      'method': method,
    }, 'Could not start the payment.');
  }

  /// Returns null on success, else a user-friendly error message.
  Future<String?> confirmPayment({required String bookingId}) async {
    return _call('confirmPayment', {
      'paymentId': bookingId,
    }, 'Could not confirm the payment.');
  }

  Future<String?> _call(
    String function,
    Map<String, dynamic> data,
    String fallback,
  ) async {
    try {
      await FirebaseFunctions.instance.httpsCallable(function).call(data);
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
