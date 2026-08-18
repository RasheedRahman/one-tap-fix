import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/auth_failure.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Central auth state for the whole mobile app.
///
/// Responsibilities:
/// - track Firebase Auth state and the Firestore `users/{uid}` profile,
/// - phone OTP (send / verify / resend) and email fallback,
/// - first-run onboarding: create the profile doc with a chosen role,
/// - expose `status`, `user`, `busy`, `authError` to the UI.
class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  StreamSubscription<User?>? _authSubscription;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _uid;
  String? _authError;
  bool _busy = false;

  /// OTP session state (valid while this provider instance lives).
  String? _verificationId;
  String? _resendToken;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get busy => _busy;
  String? get authError => _authError;

  /// True once the user picked a role and the profile doc exists.
  bool get isOnboardingComplete =>
      _user != null && _user!.onboardingCompleted;

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _uid = null;
      _authError = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    _status = AuthStatus.unknown; // show splash while the profile loads
    _authError = null;
    notifyListeners();
    await _loadUser(firebaseUser.uid);
  }

  Future<void> _loadUser(String uid) async {
    _uid = uid;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      _user = snap.exists ? UserModel.fromJson(uid, snap.data()!) : null;
      _authError = null;
    } catch (_) {
      _user = null;
      _authError = 'Could not load your profile. Check your connection.';
    }
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Retry path for the AuthErrorScreen.
  Future<void> retryLoadUser() async {
    final uid = _uid;
    if (uid == null) return;
    await _loadUser(uid);
  }

  // ---------------------------------------------------------------------
  // Phone OTP
  // ---------------------------------------------------------------------

  Future<void> sendOtp({
    required String phone,
    required void Function() onCodeSent,
    required void Function(String message) onFailure,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: _onAutoVerified,
        verificationFailed: (e) => onFailure(AuthFailure.message(e)),
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken?.toString();
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onFailure(AuthFailure.message(e));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp({
    required String phone,
    required void Function() onCodeSent,
    required void Function(String message) onFailure,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: int.tryParse(_resendToken ?? ''),
        verificationCompleted: _onAutoVerified,
        verificationFailed: (e) => onFailure(AuthFailure.message(e)),
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken?.toString();
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onFailure(AuthFailure.message(e));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Returns null on success, otherwise a user-friendly error message.
  Future<String?> verifyOtp(String smsCode) async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      return 'OTP session expired. Please request a new code.';
    }
    _busy = true;
    notifyListeners();
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return AuthFailure.message(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Android SMS Retriever / iOS auto-fill can verify without typing.
  Future<void> _onAutoVerified(PhoneAuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
    } catch (_) {
      // Fall back to manual OTP entry.
    }
  }

  // ---------------------------------------------------------------------
  // Email fallback
  // ---------------------------------------------------------------------

  Future<String?> signInWithEmail(String email, String password) async {
    _busy = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return AuthFailure.message(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> signUpWithEmail(String email, String password) async {
    _busy = true;
    notifyListeners();
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return AuthFailure.message(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------

  /// Writes `users/{uid}` with the chosen role. Role is written exactly
  /// once; Firestore rules forbid changing it later.
  /// Returns null on success, otherwise a user-friendly error message.
  Future<String?> completeProfile({
    required String role,
    required String name,
  }) async {
    if (!AppRoles.mobileSelectable.contains(role)) {
      return 'Invalid role selection.';
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Not signed in. Please try again.';

    _busy = true;
    notifyListeners();
    final now = DateTime.now();
    try {
      await _db.collection('users').doc(uid).set({
        'role': role,
        'name': name.trim(),
        'phone': _auth.currentUser?.phoneNumber,
        'email': _auth.currentUser?.email,
        'photoUrl': null,
        'locale': AppConstants.defaultLocale,
        'languages': [AppConstants.defaultLocale],
        'isBlocked': false,
        'isOnline': false,
        'onboardingCompleted': true,
        'createdAt': now,
        'updatedAt': now,
      });
      await _loadUser(uid);
      return null;
    } on FirebaseException catch (e) {
      return AuthFailure.message(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Local state resets through the auth state listener either way.
    }
  }

  /// Stores the device push token for FCM (matching notifications).
  /// Best-effort: failures are ignored (token refreshes retry later).
  Future<void> saveFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': token});
    } catch (_) {
      // Non-fatal.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
