import 'package:firebase_auth/firebase_auth.dart';

/// Maps Firebase exceptions to short, user-friendly messages.
class AuthFailure {
  AuthFailure._();

  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          return 'Invalid email or password.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a minute and try again.';
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
