import 'package:firebase_auth/firebase_auth.dart';

/// Maps Firebase exceptions to short, user-friendly messages.
/// All auth screens surface errors through this helper.
class AuthFailure {
  AuthFailure._();

  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return 'Incorrect OTP. Please try again.';
        case 'invalid-phone-number':
          return 'Enter a valid mobile number.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a minute and try again.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Try again.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'network-request-failed':
        case 'channel-error':
          return 'No internet connection. Check and try again.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    if (error is FirebaseException) {
      return error.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
