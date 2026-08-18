import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/fcm_service.dart';
import '../../providers/app_events.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/technician_dashboard_screen.dart';
import '../earnings/earnings_screen.dart';
import '../jobs/jobs_screen.dart';
import '../profile/technician_profile_screen.dart';
import '../store/store_screen.dart';

/// Technician experience: Dashboard / Jobs / Earnings / Store / Profile.
class TechnicianShell extends StatefulWidget {
  const TechnicianShell({super.key});

  @override
  State<TechnicianShell> createState() => _TechnicianShellState();
}

class _TechnicianShellState extends State<TechnicianShell> {
  int _index = 0;
  StreamSubscription<String>? _events;

  @override
  void initState() {
    super.initState();
    _events = context.read<AppEvents>().stream.listen(_onEvent);
    // FCM wiring (idempotent); notification taps jump to the Jobs tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.initialize(
        context.read<AuthProvider>(),
        context.read<AppEvents>(),
      );
    });
  }

  void _onEvent(String event) {
    if (event == AppEvents.openTechnicianJobs && mounted) {
      setState(() => _index = 1);
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      TechnicianDashboardScreen(),
      JobsScreen(),
      EarningsScreen(),
      StoreScreen(),
      TechnicianProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Store',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
