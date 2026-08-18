import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Thumbnail chip for a picked photo or video, with a remove button.
class ImageThumbnail extends StatelessWidget {
  const ImageThumbnail({
    super.key,
    required this.file,
    this.isVideo = false,
    required this.onRemove,
  });

  final XFile file;
  final bool isVideo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(file.path),
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 88,
              height: 88,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
        if (isVideo)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
