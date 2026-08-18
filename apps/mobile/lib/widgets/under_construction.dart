import 'package:flutter/material.dart';

/// Placeholder body for tabs that are scheduled in upcoming features.
/// Explicitly marks what the plan schedules for that screen.
class UnderConstruction extends StatelessWidget {
  const UnderConstruction({super.key, required this.feature});

  final String feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded,
                size: 52, color: scheme.outline),
            const SizedBox(height: 14),
            Text(
              feature,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Scheduled in an upcoming feature',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
