import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Analytics dashboard (plan §4.5): live counters computed from
/// Firestore queries. Approximations are bounded by the dashboard
/// query limits — precise aggregates live in the daily reports.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);

    return ListView(
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _CountCard(
              label: 'Customers',
              icon: Icons.people_outline_rounded,
              stream: db
                  .collection('users')
                  .where('role', isEqualTo: 'customer')
                  .limit(1000)
                  .snapshots(),
            ),
            _CountCard(
              label: 'Technicians',
              icon: Icons.handyman_outlined,
              stream: db.collection('technicians').limit(1000).snapshots(),
            ),
            _CountCard(
              label: 'Jobs today',
              icon: Icons.work_outline_rounded,
              stream: db
                  .collection('bookings')
                  .where('createdAt', isGreaterThanOrEqualTo: startOfToday)
                  .limit(1000)
                  .snapshots(),
            ),
            _CountCard(
              label: 'Open complaints',
              icon: Icons.assignment_late_outlined,
              stream: db
                  .collection('complaints')
                  .where('status', isEqualTo: 'submitted')
                  .limit(1000)
                  .snapshots(),
            ),
            _CountCard(
              label: 'Active technicians',
              icon: Icons.radar_rounded,
              stream: db
                  .collection('technicians')
                  .where('isAvailable', isEqualTo: true)
                  .limit(1000)
                  .snapshots(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Revenue (this month)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('payments')
              .where('type', isEqualTo: 'payment')
              .where('status', isEqualTo: 'succeeded')
              .where('paidAt', isGreaterThanOrEqualTo: startOfMonth)
              .limit(1000)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Card(
                child: ListTile(title: Text('Could not load.')),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final revenue = snapshot.data!.docs.fold<int>(
              0,
              (total, d) =>
                  total + ((d.data()['amount'] as num?)?.toInt() ?? 0),
            );
            return Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(
                  '₹$revenue',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text('Settled payments this month'),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Top technicians by rating',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('technicians')
              .where('ratingsCount', isGreaterThan: 0)
              .orderBy('rating', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Card(
                child: ListTile(title: Text('Could not load.')),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final rows = snapshot.data!.docs;
            if (rows.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No ratings yet.'),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final doc in rows.take(5))
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (doc.data()['rating'] as num?)
                                  ?.toDouble()
                                  .toStringAsFixed(1) ??
                              '0.0',
                        ),
                      ),
                      title: Text('Technician ${doc.id.substring(0, 8)}'),
                      subtitle: Text(
                        '${(doc.data()['ratingsCount'] as num?)?.toInt() ?? 0} reviews · '
                        '${(doc.data()['completedJobs'] as num?)?.toInt() ?? 0} jobs',
                      ),
                      trailing: _completionChip(doc.data()),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _completionChip(Map<String, dynamic> data) {
    final completed = (data['completedJobs'] as num?)?.toInt() ?? 0;
    final cancelled = (data['cancelledJobs'] as num?)?.toInt() ?? 0;
    final total = completed + cancelled;
    final rate = total == 0 ? 0 : (completed / total * 100).round();
    return Chip(
      label: Text('$rate% completion'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.icon,
    required this.stream,
  });

  final String label;
  final IconData icon;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return SizedBox(
          width: 190,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: scheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
