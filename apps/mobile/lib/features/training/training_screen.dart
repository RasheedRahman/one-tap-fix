import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/training_video_model.dart';

/// Training & safety videos (plan §5). Launched externally so no video
/// player dependency is needed at this stage.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  Future<void> _play(TrainingVideoModel video) async {
    final uri = Uri.tryParse(video.url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Invalid video link.')));
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Training & safety')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('training_videos')
            .where('isActive', isEqualTo: true)
            .orderBy('sortOrder')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load videos.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final videos = snapshot.data!.docs
              .map((d) => TrainingVideoModel.fromJson(d.id, d.data()))
              .toList();
          if (videos.isEmpty) {
            return Center(
              child: Text(
                'No training videos yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final video = videos[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  title: Text(
                    video.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    video.durationMinutes > 0
                        ? '${video.durationMinutes} min'
                        : 'Video',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => _play(video),
                    child: const Text('Watch'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
