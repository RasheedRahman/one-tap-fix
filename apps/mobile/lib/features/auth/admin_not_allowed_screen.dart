import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

/// The admin role is web-only per implementation_plan.docx (Flutter Web
/// admin panel). Mobile blocks admin sign-ins and points to the panel.
class AdminNotAllowedScreen extends StatelessWidget {
  const AdminNotAllowedScreen({super.key});

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
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 56,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Admin account detected',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The admin panel is available on the web.\n'
                    'Sign out to use this app as a customer or technician.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Sign out',
                    icon: Icons.logout_rounded,
                    onPressed: () => context.read<AuthProvider>().signOut(),
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
