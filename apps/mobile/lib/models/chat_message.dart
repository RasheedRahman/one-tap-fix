import 'package:cloud_firestore/cloud_firestore.dart';

/// Message types supported in a job chat.
abstract final class ChatMessageType {
  static const String text = 'text';
  static const String image = 'image';
}

/// A single message in `chats/{bookingId}/messages/{msgId}`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.text = '',
    this.mediaUrl,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final DateTime createdAt;
  final String text;
  final String? mediaUrl;

  bool get isImage => type == ChatMessageType.image;
  bool get isText => type == ChatMessageType.text;

  factory ChatMessage.fromJson(String id, Map<String, dynamic> json) {
    return ChatMessage(
      id: id,
      chatId: json['chatId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      type: json['type'] as String? ?? ChatMessageType.text,
      text: json['text'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Payload written by the client; `createdAt` is a server timestamp
  /// (rules require it to equal the server time on create).
  Map<String, dynamic> toDocument() => {
    'chatId': chatId,
    'senderId': senderId,
    'type': type,
    'text': text,
    'mediaUrl': mediaUrl,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
