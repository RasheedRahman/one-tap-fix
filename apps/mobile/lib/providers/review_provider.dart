import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/review_model.dart';

/// Reviews & ratings (plan §2.4): customers rate technicians after a
/// completed job. Aggregation into `technicians/{uid}.rating` happens
/// server-side via the `onReviewWritten` trigger.
class ReviewProvider extends ChangeNotifier {
  ReviewProvider({FirebaseAuth? auth, FirebaseFirestore? db, FirebaseStorage? storage})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static const int maxPhotos = 3;
  static const int maxPhotoBytes = 5 * 1024 * 1024;

  String get _uid => _auth.currentUser?.uid ?? '';

  /// The review for a booking, or null if not reviewed yet.
  Stream<ReviewModel?> streamReviewForBooking(String bookingId) {
    return _db
        .collection('reviews')
        .doc(bookingId)
        .snapshots()
        .map((snap) =>
            snap.exists ? ReviewModel.fromJson(bookingId, snap.data()!) : null);
  }

  /// All reviews for a technician (used on the technician profile).
  Stream<List<ReviewModel>> streamReviewsForTechnician(String technicianId) {
    return _db
        .collection('reviews')
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ReviewModel.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  /// Submits a review for a completed booking. Photos are uploaded
  /// first, then the review doc is created (id = bookingId, so only one
  /// review per booking — rules enforce it).
  ///
  /// Returns null on success, else a user-friendly error message.
  Future<String?> submitReview({
    required String bookingId,
    required String technicianId,
    required int rating,
    String reviewText = '',
    List<String> photoPaths = const [],
    String? customerName,
  }) async {
    if (rating < 1 || rating > 5) return 'Rating must be 1–5 stars.';
    if (_uid.isEmpty) return 'Not signed in.';
    try {
      final photoUrls = <String>[];
      for (final path in photoPaths) {
        final file = File(path);
        final size = await file.length();
        if (size > maxPhotoBytes) {
          return 'Photos must be under 5 MB each.';
        }
        final name =
            '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}'
            '.${path.split('.').last}';
        final ref = _storage.ref('reviews/$bookingId/photos/$name');
        final task = await ref.putFile(file);
        photoUrls.add(await task.ref.getDownloadURL());
      }

      await _db.collection('reviews').doc(bookingId).set(
            ReviewModel(
              bookingId: bookingId,
              customerId: _uid,
              technicianId: technicianId,
              rating: rating,
              reviewText: reviewText.trim(),
              photos: photoUrls,
              customerName: customerName,
              createdAt: DateTime.now(),
            ).toDocument(),
          );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not submit the review.';
    } catch (_) {
      return 'Could not submit the review.';
    }
  }
}
