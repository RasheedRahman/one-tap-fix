import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/technician_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/technician_provider.dart';
import '../membership/membership_screen.dart';

/// Technician earnings (plan §3.6): balance, daily & monthly totals,
/// subscription status, and the list of settled payments.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';
    final tech = context.watch<TechnicianProvider>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: uid.isEmpty
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BalanceCard(tech: tech),
                const SizedBox(height: 12),
                _MonthCards(tech: tech),
                const SizedBox(height: 12),
                _SubscriptionCard(tech: tech),
                const SizedBox(height: 16),
                Text(
                  'Settled payments',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .where('technicianId', isEqualTo: uid)
                      .where('type', isEqualTo: 'payment')
                      .orderBy('paidAt', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load payments.'),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final payments = snapshot.data!.docs.where((d) {
                      return d.data()['status'] == 'succeeded' &&
                          d.data()['paidAt'] != null;
                    }).toList();
                    if (payments.isEmpty) {
                      return const _NoPayments();
                    }
                    return Column(
                      children: [
                        for (final doc in payments) _PaymentRow(doc: doc),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.tech});

  final TechnicianModel? tech;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balance = tech?.balance ?? 0;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Withdrawable balance',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹$balance',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: const Text(
                'Withdraw — payouts arrive with the admin panel',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCards extends StatelessWidget {
  const _MonthCards({required this.tech});

  final TechnicianModel? tech;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = EarningsScreen.monthKey(now);
    final prevMonth = EarningsScreen.monthKey(
      DateTime(now.year, now.month - 1, 1),
    );
    final tech = this.tech;
    final today = tech?.earningsIn(thisMonth) ?? 0;
    final monthly = tech?.earningsIn(prevMonth) ?? 0;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            label: 'This month',
            value: today,
            icon: Icons.today_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            label: 'Last month',
            value: monthly,
            icon: Icons.calendar_month_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            label: 'Total earned',
            value: tech?.totalEarned ?? 0,
            icon: Icons.trending_up_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              '₹$value',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.tech});

  final TechnicianModel? tech;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = tech?.hasActiveSubscription ?? false;
    final plan = tech?.subscription?['plan'] as String?;
    final expiryRaw = tech?.subscription?['expiry'];

    return Card(
      child: ListTile(
        leading: Icon(
          active
              ? Icons.workspace_premium_rounded
              : Icons.calendar_month_rounded,
          color: active ? scheme.tertiary : scheme.outline,
        ),
        title: Text(
          active ? '${plan ?? 'Pro'} plan active' : 'No subscription yet',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          active
              ? 'Renews ${shortDate((expiryRaw as Timestamp?)?.toDate() ?? DateTime.now())}'
              : 'Subscribe monthly or yearly for lower commission.',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MembershipScreen(),
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = doc.data();
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final method = data['method'] as String? ?? '';
    final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
    final bookingId = data['bookingId'] as String? ?? doc.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.green.shade50,
          child: Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: Colors.green.shade600,
          ),
        ),
        title: Text(
          '₹$amount · ${method.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          paidAt == null ? bookingId : '${shortDateTime(paidAt)} · $bookingId',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.receipt_long_outlined, color: scheme.outline),
      ),
    );
  }
}

class _NoPayments extends StatelessWidget {
  const _NoPayments();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              'No settled payments yet. Payments appear here once '
              'customers pay for completed jobs.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
