import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/admin_api.dart';
import '../../models/payment_model.dart';
import '../../models/technician_model.dart';

/// Payment management (plan §4.4): track settlements and process
/// technician payouts against their withdrawable balance.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _payouts = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Payments')),
            ButtonSegment(value: true, label: Text('Payouts')),
          ],
          selected: {_payouts},
          onSelectionChanged: (s) => setState(() => _payouts = s.first),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _payouts ? const _PayoutsView() : const _PaymentsView(),
        ),
      ],
    );
  }
}

class _PaymentsView extends StatelessWidget {
  const _PaymentsView();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('type', isEqualTo: 'payment')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load payments.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final payments = snapshot.data!.docs
            .map((d) => PaymentModel.fromJson(d.id, d.data()))
            .toList();
        if (payments.isEmpty) {
          return const Center(child: Text('No payments yet.'));
        }
        return ListView.separated(
          itemCount: payments.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = payments[index];
            return ListTile(
              leading: CircleAvatar(
                child: Icon(switch (p.status) {
                  'succeeded' => Icons.check_rounded,
                  'refunded' => Icons.replay_circle_filled_outlined,
                  _ => Icons.schedule_rounded,
                }),
              ),
              title: Text(
                '₹${p.amount} · ${p.method.toUpperCase()} · ${p.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${p.customerId?.substring(0, 8) ?? '—'} → ${p.technicianId?.substring(0, 8) ?? '—'}',
              ),
              trailing: Chip(
                label: Text(p.status),
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        );
      },
    );
  }
}

class _PayoutsView extends StatelessWidget {
  const _PayoutsView();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('type', isEqualTo: 'payout')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        final payouts =
            snapshot.data?.docs
                .map((d) => PaymentModel.fromJson(d.id, d.data()))
                .toList() ??
            const <PaymentModel>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PayoutForm(),
            const SizedBox(height: 16),
            Expanded(
              child: payouts.isEmpty
                  ? const Center(child: Text('No payouts yet.'))
                  : ListView.separated(
                      itemCount: payouts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = payouts[index];
                        return ListTile(
                          title: Text(
                            '₹${p.amount}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${p.id} · tech ${p.technicianId?.substring(0, 8) ?? '—'}',
                          ),
                          trailing: Chip(
                            label: Text(p.status),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PayoutForm extends StatefulWidget {
  const _PayoutForm();

  @override
  State<_PayoutForm> createState() => _PayoutFormState();
}

class _PayoutFormState extends State<_PayoutForm> {
  String? _technicianId;
  final TextEditingController _amount = TextEditingController();
  bool _busy = false;
  Map<String, TechnicianModel> _technicians = {};

  Future<void> _loadTechnicians() async {
    final snap = await FirebaseFirestore.instance
        .collection('technicians')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    _technicians = {
      for (final d in snap.docs) d.id: TechnicianModel.fromJson(d.id, d.data()),
    };
  }

  Future<void> _submit() async {
    final id = _technicianId;
    final amount = int.tryParse(_amount.text.trim());
    if (id == null || amount == null || amount <= 0) return;
    setState(() => _busy = true);
    final error = await AdminApi.processPayout(
      technicianId: id,
      amount: amount,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'Payout of ₹$amount processed'),
          backgroundColor: error == null ? Colors.green : null,
        ),
      );
    if (error == null) _amount.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FutureBuilder<void>(
          future: _loadTechnicians(),
          builder: (context, snapshot) {
            final busyLoading =
                snapshot.connectionState == ConnectionState.waiting;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Process a payout',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _technicianId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Technician',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in _technicians.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          '${entry.value.name.isEmpty ? entry.key.substring(0, 8) : entry.value.name}'
                          ' · balance ₹${entry.value.balance}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busyLoading
                      ? null
                      : (v) => setState(() => _technicianId = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _busy || busyLoading ? null : _submit,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Pay out'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
