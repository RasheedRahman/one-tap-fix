import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';

/// Job chat (plan §2.4): live messages with photos under
/// `chats/{bookingId}/messages`, plus the masked-contact callable.
///
/// The chat document itself is created server-side on job acceptance;
/// clients only write messages (rules enforce participant membership).
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  static const int maxPhotoBytes = 5 * 1024 * 1024;

  String get _uid => _auth.currentUser?.uid ?? '';

  /// Live messages, newest last (UI renders the list reversed).
  Stream<List<ChatMessage>> streamMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatMessage.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  /// The chat document (`chats/{bookingId}`), null while it does not exist.
  Stream<Map<String, dynamic>?> streamChat(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((snap) => snap.data());
  }

  /// Sends a text message. Returns null on success, else an error message.
  Future<String?> sendText({
    required String chatId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (_uid.isEmpty) return 'Not signed in.';
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(
            ChatMessage(
              id: '',
              chatId: chatId,
              senderId: _uid,
              type: ChatMessageType.text,
              text: trimmed,
              createdAt: DateTime.now(),
            ).toDocument(),
          );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not send the message.';
    } catch (_) {
      return 'Could not send the message.';
    }
  }

  /// Uploads a photo and sends it as an image message.
  /// Returns null on success, else an error message.
  Future<String?> sendImage({
    required String chatId,
    required String filePath,
  }) async {
    if (_uid.isEmpty) return 'Not signed in.';
    try {
      final file = File(filePath);
      final size = await file.length();
      if (size > maxPhotoBytes) {
        return 'Photos must be under 5 MB.';
      }
      final name =
          '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}'
          '.${filePath.split('.').last}';
      final ref = _storage.ref('chats/$chatId/photos/$name');
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();

      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(
            ChatMessage(
              id: '',
              chatId: chatId,
              senderId: _uid,
              type: ChatMessageType.image,
              mediaUrl: url,
              createdAt: DateTime.now(),
            ).toDocument(),
          );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not send the photo.';
    } catch (_) {
      return 'Could not send the photo.';
    }
  }

  /// Masked contact (plan §2.4): the server verifies the caller is a
  /// participant of the booking and returns the other party's
  /// `{name, phone}`. Returns null on failure.
  Future<({String name, String phone})?> getContact(String bookingId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getContact');
      final result = await callable.call({'bookingId': bookingId});
      final data = result.data as Map?;
      final name = data?['name'] as String? ?? 'Contact';
      final phone = data?['phone'] as String? ?? '';
      if (phone.isEmpty) return null;
      return (name: name, phone: phone);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('getContact failed: ${e.code} ${e.message}');
      return null;
    } catch (_) {
      return null;
    }
  }
}
