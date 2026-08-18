import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/auth_failure.dart';
import '../models/user_model.dart';

enum AdminAuthStatus { unknown, signedOut, authenticated, accessDenied }

/// Auth state for the admin web panel.
/// Only users whose `users/{uid}` doc has role == "admin" get in.
class AdminAuthProvider extends ChangeNotifier {
  AdminAuthProvider({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  StreamSubscription<User?>? _authSubscription;

  AdminAuthStatus _status = AdminAuthStatus.unknown;
  UserModel? _admin;
  String? _error;

  AdminAuthStatus get status => _status;
  UserModel? get admin => _admin;
  String? get error => _error;

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _admin = null;
      _error = null;
      _status = AdminAuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _status = AdminAuthStatus.unknown;
    notifyListeners();

    try {
      final snap = await _db.collection('users').doc(firebaseUser.uid).get();
      final data = snap.data();
      if (!snap.exists || data == null || data['role'] != 'admin') {
        _status = AdminAuthStatus.accessDenied;
      } else {
        _admin = UserModel.fromJson(firebaseUser.uid, data);
        _status = AdminAuthStatus.authenticated;
      }
      _error = null;
    } catch (_) {
      _error = 'Could not verify your access. Check your connection.';
      _status = AdminAuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return AuthFailure.message(e);
    }
  }

  Future<void> retry() async {
    final user = _auth.currentUser;
    if (user == null) {
      _status = AdminAuthStatus.signedOut;
      notifyListeners();
      return;
    }
    await _onAuthStateChanged(user);
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // State resets through the auth listener.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
