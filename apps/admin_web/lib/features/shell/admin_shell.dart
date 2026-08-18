import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_auth_provider.dart';
import '../analytics/analytics_screen.dart';
import '../complaints/complaints_screen.dart';
import '../jobs/jobs_screen.dart';
import '../payments/payments_screen.dart';
import '../services/services_screen.dart';
import '../store/store_screen.dart';
import '../training/training_videos_screen.dart';
import '../users/users_screen.dart';

/// Admin shell: rail navigation across the eight sections of the plan
/// (Analytics, Jobs, Users, Payments, Services, Complaints, Store,
/// Training).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminAuthProvider>().admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MEP Connect Admin'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  admin?.name ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => context.read<AdminAuthProvider>().signOut(),
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: Text('Analytics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.work_outline_rounded),
                selectedIcon: Icon(Icons.work_rounded),
                label: Text('Jobs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: Text('Payments'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.miscellaneous_services_outlined),
                selectedIcon: Icon(Icons.miscellaneous_services_rounded),
                label: Text('Services'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_late_outlined),
                selectedIcon: Icon(Icons.assignment_late_rounded),
                label: Text('Complaints'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: Text('Store'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.play_circle_outline_rounded),
                selectedIcon: Icon(Icons.play_circle_rounded),
                label: Text('Training'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: switch (_index) {
                0 => const AnalyticsScreen(),
                1 => const JobsScreen(),
                2 => const UsersScreen(),
                3 => const PaymentsScreen(),
                4 => const ServicesScreen(),
                5 => const ComplaintsScreen(),
                6 => const StoreScreen(),
                _ => const TrainingVideosScreen(),
              },
            ),
          ),
        ],
      ),
    );
  }
}
