import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrappers around the admin Cloud Functions (plan §4).
class AdminApi {
  /// Returns null on success, else a user-friendly error message.
  static Future<String?> _call(
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

  static Future<String?> approveKyc(String uid, String status) => _call(
    'approveTechnicianKyc',
    {'uid': uid, 'status': status},
    'Could not update KYC status.',
  );

  static Future<String?> resolveComplaint({
    required String bookingId,
    required String resolution,
    required bool refund,
  }) => _call('resolveComplaint', {
    'bookingId': bookingId,
    'resolution': resolution,
    'refund': refund,
  }, 'Could not resolve the complaint.');

  static Future<String?> processPayout({
    required String technicianId,
    required int amount,
  }) => _call('processPayout', {
    'technicianId': technicianId,
    'amount': amount,
  }, 'Could not process the payout.');

  /// Cancels a technician's active subscription (plan §3.7).
  static Future<String?> cancelSubscription(String technicianId) => _call(
    'cancelSubscription',
    {'technicianId': technicianId},
    'Could not cancel the subscription.',
  );

  /// Sends Firebase's password-reset email (plan §4.1 reset passwords).
  static Future<String?> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send the reset email.';
    } catch (_) {
      return 'Could not send the reset email.';
    }
  }
}
