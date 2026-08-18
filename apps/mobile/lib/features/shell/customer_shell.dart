import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/fcm_service.dart';
import '../../providers/app_events.dart';
import '../../providers/auth_provider.dart';
import '../bookings/bookings_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

/// Customer experience: Home / Bookings / Profile.
/// Tab content is swapped in as the plan's features land.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  StreamSubscription<String>? _events;

  @override
  void initState() {
    super.initState();
    // FCM wiring (idempotent) so customers receive booking updates;
    // notification taps jump to the Bookings tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _events = context.read<AppEvents>().stream.listen(_onEvent);
      FcmService.initialize(
        context.read<AuthProvider>(),
        context.read<AppEvents>(),
      );
    });
  }

  void _onEvent(String event) {
    if (event == AppEvents.openCustomerBookings && mounted) {
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
    final pages = const [HomeScreen(), BookingsScreen(), ProfileScreen()];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Bookings',
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
