import 'package:flutter_test/flutter_test.dart';

import 'package:mep_connect_mobile/models/training_video_model.dart';

void main() {
  group('TrainingVideoModel', () {
    test('parses a video document', () {
      final video = TrainingVideoModel.fromJson('safety_first', {
        'title': 'Electrical safety on site',
        'url': 'https://youtube.com/watch?v=abc',
        'description': 'PPE and live-wire precautions.',
        'durationMinutes': 15,
        'sortOrder': 1,
        'isActive': true,
      });

      expect(video.id, 'safety_first');
      expect(video.title, 'Electrical safety on site');
      expect(video.url, 'https://youtube.com/watch?v=abc');
      expect(video.description, 'PPE and live-wire precautions.');
      expect(video.durationMinutes, 15);
      expect(video.sortOrder, 1);
      expect(video.isActive, isTrue);
    });

    test('falls back to defaults', () {
      final video = TrainingVideoModel.fromJson('x', {});

      expect(video.title, '');
      expect(video.url, '');
      expect(video.description, '');
      expect(video.durationMinutes, 0);
      expect(video.sortOrder, 0);
      expect(video.isActive, isTrue);
    });
  });
}
