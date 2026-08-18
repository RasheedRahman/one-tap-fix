import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    final now = DateTime.utc(2026, 8, 8, 12);

    test('parses a text message document', () {
      final message = ChatMessage.fromJson('msg-1', {
        'chatId': 'book-1',
        'senderId': 'tech-1',
        'type': 'text',
        'text': 'On my way',
        'createdAt': Timestamp.fromDate(now),
      });

      expect(message.chatId, 'book-1');
      expect(message.senderId, 'tech-1');
      expect(message.type, ChatMessageType.text);
      expect(message.text, 'On my way');
      expect(message.mediaUrl, isNull);
      expect(message.isText, isTrue);
      expect(message.isImage, isFalse);
      expect(message.createdAt, now.toLocal());
    });

    test('parses an image message document', () {
      final message = ChatMessage.fromJson('msg-2', {
        'chatId': 'book-1',
        'senderId': 'cust-1',
        'type': 'image',
        'mediaUrl': 'https://x.com/chat-photo.jpg',
        'createdAt': Timestamp.fromDate(now),
      });

      expect(message.isImage, isTrue);
      expect(message.mediaUrl, 'https://x.com/chat-photo.jpg');
      expect(message.text, '');
    });

    test('applies safe defaults for missing fields', () {
      final message = ChatMessage.fromJson('msg-3', {});

      expect(message.senderId, '');
      expect(message.type, ChatMessageType.text);
      expect(message.text, '');
      expect(message.mediaUrl, isNull);
    });

    test('toDocument carries a server-timestamp sentinel', () {
      final message = ChatMessage(
        id: '',
        chatId: 'book-1',
        senderId: 'cust-1',
        type: ChatMessageType.text,
        text: 'Hello',
        createdAt: DateTime.now(),
      );

      final doc = message.toDocument();
      expect(doc['senderId'], 'cust-1');
      // Server-timestamp sentinel (rules require createdAt == request.time).
      expect(doc['createdAt'], isA<FieldValue>());
    });
  });
}
