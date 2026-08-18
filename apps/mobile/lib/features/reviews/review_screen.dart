import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/review_provider.dart';

/// Customer rates a completed job (plan §2.4): 1–5 stars, optional text
/// and up to 3 photos. Creates `reviews/{bookingId}` (one per booking).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.technicianId,
    this.technicianName = '',
  });

  final String bookingId;
  final String technicianId;
  final String technicianName;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final TextEditingController _text = TextEditingController();
  final List<String> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= ReviewProvider.maxPhotos) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _photos.add(picked.path));
      }
    } catch (_) {
      // Ignore picker failures; user can retry.
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the stars to rate your technician.')),
      );
      return;
    }
    setState(() => _busy = true);
    final error = await context.read<ReviewProvider>().submitReview(
      bookingId: widget.bookingId,
      technicianId: widget.technicianId,
      rating: _rating,
      reviewText: _text.text,
      photoPaths: _photos,
      customerName: context.read<AuthProvider>().user?.name,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Thanks for your review!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rate your technician')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.technicianName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How was the job?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 40,
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i <= _rating
                          ? scheme.tertiary
                          : scheme.outlineVariant,
                    ),
                    onPressed: () => setState(() => _rating = i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              switch (_rating) {
                1 => 'Poor',
                2 => 'Fair',
                3 => 'Good',
                4 => 'Very good',
                5 => 'Excellent',
                _ => 'Tap to rate',
              },
              style: theme.textTheme.titleSmall?.copyWith(
                color: _rating == 0 ? scheme.outline : scheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Tell others about the service…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Photos (optional)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final path in _photos)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(path),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => setState(() => _photos.remove(path)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_photos.length < ReviewProvider.maxPhotos)
                InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: scheme.outline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.star_rounded),
            label: const Text('Submit review'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
