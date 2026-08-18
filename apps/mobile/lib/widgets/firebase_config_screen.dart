import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import 'app_logo.dart';

/// Shown when Firebase is not configured yet. Instructs the developer to
/// run `flutterfire configure` (see firebase/setup_guide.md).
class FirebaseConfigScreen extends StatelessWidget {
  const FirebaseConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(),
                  const SizedBox(height: 32),
                  Icon(Icons.cloud_off_rounded,
                      size: 56, color: scheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase is not configured',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${AppConstants.appName} needs Firebase config files to run.\n\n'
                    'From apps/mobile run:\n'
                    'flutterfire configure --project <project-id>\n\n'
                    'See firebase/setup_guide.md in the repo root for details.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
