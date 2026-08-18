import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../providers/booking_provider.dart';
import 'image_thumbnail.dart';

/// Photo + video attachment field for the booking form.
/// Enforces the plan's photo/video upload with size limits.
class MediaPickerField extends StatefulWidget {
  const MediaPickerField({super.key, required this.onChanged});

  final ValueChanged<List<XFile>> onChanged;

  @override
  State<MediaPickerField> createState() => _MediaPickerFieldState();
}

class _MediaPickerFieldState extends State<MediaPickerField> {
  final ImagePicker _picker = ImagePicker();

  List<XFile> _photos = [];
  XFile? _video;

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      limit: BookingProvider.maxPhotos - _photos.length,
    );
    if (picked.isEmpty) return;

    final ok = <XFile>[];
    var skipped = false;
    for (final file in picked) {
      final size = await file.length();
      if (size <= BookingProvider.maxPhotoBytes) {
        ok.add(file);
      } else {
        skipped = true;
      }
    }

    if (skipped && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Some photos were skipped (max 5 MB each).')),
        );
    }
    if (ok.isEmpty) return;

    final combined = [..._photos, ...ok];
    if (combined.length > BookingProvider.maxPhotos) {
      setState(() => _photos = combined.sublist(0, BookingProvider.maxPhotos));
    } else {
      setState(() => _photos = combined);
    }
    widget.onChanged(_photos);
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final size = await picked.length();
    if (size > BookingProvider.maxVideoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Video too large (max 50 MB).')),
          );
      }
      return;
    }
    setState(() => _video = picked);
    widget.onChanged(_photos);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final photo in _photos)
              ImageThumbnail(
                file: photo,
                onRemove: () {
                  setState(() => _photos.remove(photo));
                  widget.onChanged(_photos);
                },
              ),
            if (_video != null)
              ImageThumbnail(
                file: _video!,
                isVideo: true,
                onRemove: () {
                  setState(() => _video = null);
                  widget.onChanged(_photos);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _photos.length >= BookingProvider.maxPhotos
                  ? null
                  : _pickPhotos,
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: Text(
                _photos.length >= BookingProvider.maxPhotos
                    ? 'Max ${BookingProvider.maxPhotos} photos'
                    : 'Add photos',
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _video != null ? null : _pickVideo,
              icon: const Icon(Icons.videocam_outlined, size: 20),
              label: Text(_video != null ? 'Video added' : 'Add video'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Attach up to ${BookingProvider.maxPhotos} photos (5 MB each) and one '
          'video (50 MB). Photos and videos help the technician understand '
          'the problem.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
        ),
      ],
    );
  }
}
