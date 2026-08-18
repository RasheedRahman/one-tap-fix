import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/technician_provider.dart';
import 'widgets/job_offer_card.dart';
import 'widgets/technician_job_card.dart';

/// Technician job board (implementation_plan.docx §3.2):
/// New (offers) / Active / Completed / Cancelled jobs.
class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jobs'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'New'),
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _NewJobsTab(),
            _StatusJobsTab(
              statuses: [
                BookingStatus.accepted,
                BookingStatus.enRoute,
                BookingStatus.inProgress,
              ],
            ),
            _StatusJobsTab(statuses: [BookingStatus.completed]),
            _StatusJobsTab(statuses: [BookingStatus.cancelled]),
          ],
        ),
      ),
    );
  }
}

/// Live matching offers: bookings that list this technician as a
/// candidate and are still in the `matching` state.
class _NewJobsTab extends StatelessWidget {
  const _NewJobsTab();

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('matching.candidates', arrayContains: uid)
          .where('status', isEqualTo: BookingStatus.matching)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'Could not load new jobs.\n${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!.docs
            .map((d) => BookingModel.fromJson(d.id, d.data()))
            .toList();

        if (offers.isEmpty) {
          return const _EmptyState(
            icon: Icons.notifications_active_outlined,
            title: 'No new jobs',
            subtitle:
                'Turn on availability on the Dashboard to start receiving '
                'job offers.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => JobOfferCard(booking: offers[index]),
        );
      },
    );
  }
}

/// Active / Completed / Cancelled lists scoped to this technician.
class _StatusJobsTab extends StatelessWidget {
  const _StatusJobsTab({required this.statuses});

  final List<String> statuses;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('technicianId', isEqualTo: uid)
          .where('status', whereIn: statuses)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'Could not load jobs.\n${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data!.docs
            .map((d) => BookingModel.fromJson(d.id, d.data()))
            .toList();

        // While the technician holds an active job, the provider runs its
        // location timer faster so the customer's live map tracks them.
        if (statuses.contains(BookingStatus.accepted)) {
          context.read<TechnicianProvider>().setActiveJobTracking(
            jobs.isEmpty ? null : jobs.first.id,
          );
        }

        if (jobs.isEmpty) {
          return _EmptyState(
            icon: Icons.work_outline_rounded,
            title: 'Nothing here yet',
            subtitle: 'Jobs you accept will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              TechnicianJobCard(booking: jobs[index]),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: scheme.outline),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
