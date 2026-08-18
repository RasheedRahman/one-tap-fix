import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/booking_model.dart';
import '../models/service_model.dart';

/// Creates bookings (including media upload) and lets customers cancel
/// pending ones. Matching/dispatch is the next feature.
class BookingProvider extends ChangeNotifier {
  BookingProvider({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static const int maxPhotos = 5;
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const int maxVideoBytes = 50 * 1024 * 1024;

  bool _busy = false;
  String? _lastBookingId;

  bool get busy => _busy;
  String? get lastBookingId => _lastBookingId;

  /// Creates a booking. Media is uploaded after the doc exists so storage
  /// rules can verify the caller owns the booking.
  ///
  /// [photos] and [video] are absolute file paths (from image_picker).
  /// Returns null on success, otherwise a user-friendly error message.
  Future<String?> createBooking({
    required String customerId,
    required ServiceModel service,
    required String description,
    required List<String> photos,
    String? video,
    required DateTime scheduledAt,
    required BookingLocation location,
    required bool isEmergency,
  }) async {
    _busy = true;
    notifyListeners();

    final docRef = _db.collection('bookings').doc();
    final now = DateTime.now();

    final bookingData = <String, dynamic>{
      'bookingId': _generateBookingId(),
      'customerId': customerId,
      'technicianId': null,
      'categoryId': service.id,
      'categoryName': service.name,
      'description': description.trim(),
      'mediaUrls': <String>[],
      'scheduledAt': scheduledAt,
      'status': BookingStatus.pending,
      'location': location.toJson(),
      'pricing': BookingPricing(
        minCharge: service.minCharge,
        serviceCharge: service.serviceCharge,
        gstPercent: service.gstPercent,
      ).toJson(),
      'isEmergency': isEmergency,
      'createdAt': now,
      'updatedAt': now,
    };

    try {
      // 1) Create the booking doc (mediaUrls empty).
      await docRef.set(bookingData);

      // 2) Upload media to bookings/{bookingId}/problem_photos|videos.
      final mediaUrls = <String>[];
      try {
        for (final path in photos) {
          final url = await _uploadMedia(
            bookingId: docRef.id,
            folder: 'problem_photos',
            filePath: path,
          );
          mediaUrls.add(url);
        }
        if (video != null) {
          final url = await _uploadMedia(
            bookingId: docRef.id,
            folder: 'problem_videos',
            filePath: video,
          );
          mediaUrls.add(url);
        }
      } catch (_) {
        // Roll back the booking so no orphan doc remains.
        await docRef.delete();
        return 'Could not upload your photos/video. Please try again.';
      }

      // 3) Attach media URLs.
      await docRef.update({
        'mediaUrls': mediaUrls,
        'updatedAt': DateTime.now(),
      });

      _lastBookingId = docRef.id;
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not create the booking. Please try again.';
    } catch (_) {
      return 'Could not create the booking. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String> _uploadMedia({
    required String bookingId,
    required String folder,
    required String filePath,
  }) async {
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}'
        '.${filePath.split('.').last}';
    final ref = _storage.ref('bookings/$bookingId/$folder/$fileName');
    final task = await ref.putFile(File(filePath));
    return task.ref.getDownloadURL();
  }

  /// Cancels a booking the customer is allowed to cancel.
  ///
  /// While the booking is still waiting (`pending`/`matching`) the status
  /// is updated client-side (rules allow it). Once a technician has been
  /// assigned (`accepted`/`en_route`) the server callable `cancelJob`
  /// handles it, because the technician pool and stats must be updated.
  Future<String?> cancelBooking(BookingModel booking) async {
    if (booking.canCancelByClient) {
      try {
        await _db.collection('bookings').doc(booking.id).update({
          'status': BookingStatus.cancelled,
          'cancellationReason': 'cancelled_by_customer',
          'cancelledAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
        return null;
      } on FirebaseException catch (e) {
        return e.message ?? 'Could not cancel the booking. Please try again.';
      } catch (_) {
        return 'Could not cancel the booking. Please try again.';
      }
    }
    if (booking.canCancelAssignedByCustomer) {
      return _callServer(
        'cancelJob',
        booking.id,
        'cancel',
        'This booking can no longer be cancelled.',
      );
    }
    return 'This booking can no longer be cancelled.';
  }

  Future<String?> _callServer(
    String callableName,
    String bookingId,
    String actionLabel,
    String notAllowedMessage,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(callableName);
      await callable.call({'bookingId': bookingId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return switch (e.code) {
        'INVALID_TRANSITION' => notAllowedMessage,
        'NOT_A_PARTICIPANT' => 'This booking does not belong to you.',
        'unauthenticated' => 'Not signed in.',
        _ => e.message ?? 'Could not $actionLabel. Please try again.',
      };
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  static String _generateBookingId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final code = List.generate(
      6,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
    return 'MEP-$code';
  }
}
