import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../history/service_history_screen.dart';

/// Customer profile: personal details, service history, sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(child: Icon(Icons.person_rounded)),
            title: Text(user?.name ?? ''),
            subtitle: Text(user?.phone ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Service history'),
            subtitle: const Text('Past services, invoices & technicians'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServiceHistoryScreen(),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => context.read<AuthProvider>().signOut(),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
