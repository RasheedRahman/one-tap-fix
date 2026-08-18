import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/complaint_model.dart';

/// Complaints & refunds (plan §2.8): photos upload to storage first,
/// then the `submitComplaint` callable creates the complaint document
/// and auto-refunds qualifying paid jobs. Clients never write to
/// `complaints/` or the booking's `complaint` map directly.
class ComplaintProvider extends ChangeNotifier {
  ComplaintProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static const int maxPhotos = 3;
  static const int maxPhotoBytes = 5 * 1024 * 1024;

  String get _uid => _auth.currentUser?.uid ?? '';

  /// The complaint for a booking, or null if none exists.
  Stream<ComplaintModel?> streamComplaint(String bookingId) {
    return _db
        .collection('complaints')
        .doc(bookingId)
        .snapshots()
        .map(
          (snap) => snap.exists
              ? ComplaintModel.fromJson(bookingId, snap.data()!)
              : null,
        );
  }

  /// Uploads photos, then submits the complaint via the callable.
  /// Returns null on success, else a user-friendly error message.
  Future<String?> submitComplaint({
    required String bookingId,
    required String reason,
    String description = '',
    List<String> photoPaths = const [],
  }) async {
    if (!ComplaintReasons.all.contains(reason)) {
      return 'Invalid complaint reason.';
    }
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
        final ref = _storage.ref('complaints/$bookingId/photos/$name');
        final task = await ref.putFile(file);
        photoUrls.add(await task.ref.getDownloadURL());
      }

      await FirebaseFunctions.instance.httpsCallable('submitComplaint').call({
        'bookingId': bookingId,
        'reason': reason,
        'description': description.trim(),
        'photoUrls': photoUrls,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not submit the complaint.';
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not submit the complaint.';
    } catch (_) {
      return 'Could not submit the complaint.';
    }
  }
}
