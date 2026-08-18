import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Training & safety videos management (plan §5). Videos are external
/// links; the mobile app opens them in the browser/YouTube.
class TrainingVideosScreen extends StatefulWidget {
  const TrainingVideosScreen({super.key});

  @override
  State<TrainingVideosScreen> createState() => _TrainingVideosScreenState();
}

class _TrainingVideosScreenState extends State<TrainingVideosScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Training videos',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add video'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('training_videos')
                .orderBy('sortOrder')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Could not load videos.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final videos = snapshot.data!.docs;
              if (videos.isEmpty) {
                return const Center(child: Text('No videos yet.'));
              }
              return ListView.separated(
                itemCount: videos.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = videos[index];
                  final data = doc.data();
                  final title = data['title'] as String? ?? '';
                  final url = data['url'] as String? ?? '';
                  final minutes = (data['durationMinutes'] as num?)?.toInt() ?? 0;
                  final isActive = data['isActive'] as bool? ?? true;
                  final description = data['description'] as String? ?? '';
                  final sortOrder = (data['sortOrder'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.play_arrow_rounded),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '$url${description.isEmpty ? '' : ' · $description'}'
                      '${minutes > 0 ? ' · $minutes min' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: isActive,
                          onChanged: (_) async {
                            await doc.reference.update({
                              'isActive': !isActive,
                            });
                          },
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _openEditor(
                            context,
                            existing: doc,
                            sortOrder: sortOrder,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openEditor(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? existing,
    int sortOrder = 0,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _VideoEditorDialog(
        existing: existing,
        defaultSortOrder: sortOrder,
      ),
    );
  }
}

class _VideoEditorDialog extends StatefulWidget {
  const _VideoEditorDialog({this.existing, required this.defaultSortOrder});

  final DocumentSnapshot<Map<String, dynamic>>? existing;
  final int defaultSortOrder;

  @override
  State<_VideoEditorDialog> createState() => _VideoEditorDialogState();
}

class _VideoEditorDialogState extends State<_VideoEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _url;
  late final TextEditingController _description;
  late final TextEditingController _minutes;
  late final TextEditingController _sortOrder;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data();
    _title = TextEditingController(text: data?['title'] as String? ?? '');
    _url = TextEditingController(text: data?['url'] as String? ?? '');
    _description =
        TextEditingController(text: data?['description'] as String? ?? '');
    _minutes = TextEditingController(
      text: '${(data?['durationMinutes'] as num?)?.toInt() ?? 0}',
    );
    _sortOrder = TextEditingController(
      text: '${(data?['sortOrder'] as num?)?.toInt() ?? widget.defaultSortOrder}',
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final url = _url.text.trim();
    final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;
    if (title.isEmpty || url.isEmpty) return;
    setState(() => _busy = true);
    final data = <String, dynamic>{
      'title': title,
      'url': url,
      'description': _description.text.trim(),
      'durationMinutes': minutes,
      'sortOrder': sortOrder,
      'isActive': widget.existing?.data()?['isActive'] as bool? ?? true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      final ref = widget.existing?.reference ??
          FirebaseFirestore.instance.collection('training_videos').doc();
      await ref.set(data);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not save.')));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _description.dispose();
    _minutes.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add video' : 'Edit video'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Video URL (e.g. YouTube)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (min)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _sortOrder,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
