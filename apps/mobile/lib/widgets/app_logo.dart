import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

/// Brand mark: bolt icon in a rounded brand-colored tile + wordmark.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.compact = false,
    this.iconSize = 34,
  });

  /// When true, only the icon tile is rendered (used in app bars).
  final bool compact;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconTile = Container(
      width: iconSize + 20,
      height: iconSize + 20,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.bolt_rounded, size: iconSize, color: scheme.onPrimary),
    );

    if (compact) return iconTile;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconTile,
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            Text(
              AppConstants.tagline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
