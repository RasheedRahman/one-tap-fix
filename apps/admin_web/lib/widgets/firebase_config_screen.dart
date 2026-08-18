import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

/// Shown when Firebase is not configured yet (see firebase/setup_guide.md).
class FirebaseConfigScreen extends StatelessWidget {
  const FirebaseConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Firebase is not configured',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${AppConstants.appName} needs Firebase config files to run.\n\n'
                  'From apps/admin_web run:\n'
                  'flutterfire configure --project <project-id>\n\n'
                  'See firebase/setup_guide.md in the repo root for details.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
