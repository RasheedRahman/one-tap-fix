import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/utils/geo.dart';
import '../models/booking_model.dart';
import '../models/technician_model.dart';

/// Technician-side state: profile doc, availability toggle with live
/// location updates, the Accept/Reject calls into the matching Cloud
/// Functions, and the on-site job flow (start trip / service / complete).
class TechnicianProvider extends ChangeNotifier {
  TechnicianProvider({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const int locationUpdateIntervalSeconds = 60;
  static const int activeJobUpdateIntervalSeconds = 15;

  TechnicianModel? _profile;
  bool _busy = false;
  bool _availabilityBusy = false;
  String? _error;
  Timer? _locationTimer;
  Position? _lastPosition;
  String? _activeJobId;

  TechnicianModel? get profile => _profile;
  bool get busy => _busy;
  bool get availabilityBusy => _availabilityBusy;
  String? get error => _error;
  bool get isAvailable => _profile?.isAvailable ?? false;
  String? get activeJobId => _activeJobId;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------

  /// Reads the technicians/{uid} doc (no-op if it does not exist yet).
  Future<void> loadProfile() async {
    if (_profile != null || _uid.isEmpty) return;
    try {
      final snap = await _db.collection('technicians').doc(_uid).get();
      _profile = snap.exists
          ? TechnicianModel.fromJson(_uid, snap.data()!)
          : null;
      _error = null;
    } catch (_) {
      _error = 'Could not load your profile.';
    }
    notifyListeners();
  }

  /// Called from technician onboarding: creates technicians/{uid}.
  /// Returns null on success, otherwise a user-friendly error message.
  Future<String?> createProfile({
    required List<String> skills,
    required int experienceYears,
  }) async {
    if (_uid.isEmpty) return 'Not signed in.';
    _busy = true;
    notifyListeners();
    final now = DateTime.now();
    try {
      await _db.collection('technicians').doc(_uid).set({
        'skills': skills,
        'experienceYears': experienceYears,
        'rating': 0.0,
        'ratingsCount': 0,
        'completedJobs': 0,
        'cancelledJobs': 0,
        'isAvailable': false,
        'kycStatus': 'pending',
        'currentLocation': null,
        'createdAt': now,
        'updatedAt': now,
      });
      _profile = TechnicianModel(
        uid: _uid,
        skills: skills,
        experienceYears: experienceYears,
        rating: 0,
        ratingsCount: 0,
        completedJobs: 0,
        cancelledJobs: 0,
        isAvailable: false,
        kycStatus: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not create your technician profile.';
    } catch (_) {
      return 'Could not create your technician profile.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Availability (drives the matching engine)
  // ---------------------------------------------------------------------

  /// Turns availability on/off. While ON, the live location is written
  /// to technicians/{uid}.currentLocation every minute so the matching
  /// engine can score by distance.
  Future<String?> setAvailability(bool available) async {
    if (_uid.isEmpty) return 'Not signed in.';
    _availabilityBusy = true;
    notifyListeners();

    try {
      if (available) {
        final location = await _resolveLocation();
        if (location == null) {
          return 'Location permission is required to accept jobs.';
        }
        await _writeAvailability(isAvailable: true, location: location);
        _startLocationTimer();
      } else {
        _stopLocationTimer();
        await _writeAvailability(isAvailable: false, location: _lastPosition);
      }
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not update availability.';
    } catch (_) {
      return 'Could not update availability.';
    } finally {
      _availabilityBusy = false;
      notifyListeners();
    }
  }

  Future<Position?> _resolveLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return null;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastPosition = position;
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeAvailability({
    required bool isAvailable,
    Position? location,
  }) async {
    final now = DateTime.now();
    final updates = <String, dynamic>{
      'isAvailable': isAvailable,
      'updatedAt': now,
    };
    if (location != null) {
      updates['currentLocation'] = {
        'geopoint': GeoPoint(location.latitude, location.longitude),
        'updatedAt': now,
      };
    } else if (!isAvailable) {
      updates['currentLocation'] = null;
    }
    await _db.collection('technicians').doc(_uid).update(updates);

    final previous = _profile;
    _profile = previous == null
        ? null
        : TechnicianModel(
            uid: previous.uid,
            skills: previous.skills,
            experienceYears: previous.experienceYears,
            rating: previous.rating,
            ratingsCount: previous.ratingsCount,
            completedJobs: previous.completedJobs,
            cancelledJobs: previous.cancelledJobs,
            isAvailable: isAvailable,
            kycStatus: previous.kycStatus,
            currentLocation: location == null
                ? null
                : TechnicianLocation(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    updatedAt: now,
                  ),
            createdAt: previous.createdAt,
            updatedAt: now,
          );
  }

  void _startLocationTimer() {
    _stopLocationTimer();
    final intervalSeconds = _activeJobId != null
        ? activeJobUpdateIntervalSeconds
        : locationUpdateIntervalSeconds;
    _locationTimer = Timer.periodic(Duration(seconds: intervalSeconds), (
      _,
    ) async {
      if (!isAvailable) return;
      final location = await _resolveLocation();
      if (location == null) return;
      try {
        await _writeAvailability(isAvailable: true, location: location);
      } catch (_) {
        // Try again next tick.
      }
    });
  }

  void _stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// Call when the technician gains or loses an in-flight job. While an
  /// active job exists the location timer runs faster (15s) so the
  /// customer's live map tracks the technician closely.
  void setActiveJobTracking(String? bookingId) {
    if (_activeJobId == bookingId) return;
    _activeJobId = bookingId;
    if (_locationTimer != null && isAvailable) {
      _startLocationTimer();
    }
  }

  // ---------------------------------------------------------------------
  // Job actions (callable Cloud Functions = race-free assignment)
  // ---------------------------------------------------------------------

  Future<String?> acceptJob(String bookingId) async {
    return _callJobAction('acceptJob', {'bookingId': bookingId});
  }

  Future<String?> rejectJob(String bookingId) async {
    return _callJobAction('rejectJob', {'bookingId': bookingId});
  }

  /// On-site flow: `start_trip` / `start_service` / `complete`
  /// (see [JobActions]).
  Future<String?> updateJobStatus(String bookingId, String action) async {
    return _callJobAction('updateJobStatus', {
      'bookingId': bookingId,
      'action': action,
    });
  }

  Future<String?> cancelJob(String bookingId) async {
    return _callJobAction('cancelJob', {'bookingId': bookingId});
  }

  Future<String?> _callJobAction(String name, Map<String, dynamic> data) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(name);
      await callable.call(data);
      return null;
    } on FirebaseFunctionsException catch (e) {
      return switch (e.code) {
        'BOOKING_UNAVAILABLE' => 'This job is no longer active.',
        'NOT_A_CANDIDATE' => 'This job is no longer offered to you.',
        'NOT_A_PARTICIPANT' => 'This job does not belong to you.',
        'INVALID_TRANSITION' => 'This action is no longer available.',
        'unauthenticated' => 'Not signed in.',
        _ => e.message ?? 'Could not complete the action.',
      };
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  // ---------------------------------------------------------------------

  /// Distance from the last known technician position to a point (km).
  double? distanceKmTo(double lat, double lng) {
    final position = _lastPosition;
    if (position == null) return null;
    return Geo.haversineKm(position.latitude, position.longitude, lat, lng);
  }

  @override
  void dispose() {
    _stopLocationTimer();
    super.dispose();
  }
}
