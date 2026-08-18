import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/booking_model.dart';

/// Job management (plan §4.2): track all bookings, inspect payment and
/// complaint state, and jump to complaints for resolution.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String? _filter;

  static const _statuses = [
    'pending',
    'matching',
    'accepted',
    'en_route',
    'in_progress',
    'completed',
    'cancelled',
    'refunded',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load bookings.\n${snapshot.error}'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var bookings = snapshot.data!.docs
            .map((d) => BookingModel.fromJson(d.id, d.data()))
            .toList();
        if (_filter != null) {
          bookings = bookings.where((b) => b.status == _filter).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final s in _statuses)
                  FilterChip(
                    label: Text(s.replaceAll('_', ' ')),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (bookings.isEmpty)
              const Expanded(child: Center(child: Text('No bookings.')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return _BookingTile(booking: booking);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Text(
          booking.categoryName.isNotEmpty
              ? booking.categoryName[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(
        '${booking.bookingId} · ${booking.categoryName}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Customer ${booking.customerId.substring(0, 6)}'
        '${booking.technicianId == null ? '' : ' · Tech ${booking.technicianName}'}'
        ' · ₹${booking.amount}'
        '${booking.complaintStatus.isNotEmpty ? ' · ⚠ complaint' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(booking.status.replaceAll('_', ' ')),
            visualDensity: VisualDensity.compact,
            backgroundColor: booking.status == 'completed'
                ? scheme.tertiaryContainer
                : booking.status == 'cancelled' || booking.status == 'refunded'
                ? scheme.errorContainer
                : null,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (action) {
              if (action == 'complaints') {
                // Jump to the complaints tab is handled by the shell index;
                // for now open the complaint detail if one exists.
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'note',
                enabled: false,
                child: Text('No actions yet'),
              ),
            ],
          ),
        ],
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _BookingDetailDialog(booking: booking),
      ),
    );
  }
}

class _BookingDetailDialog extends StatelessWidget {
  const _BookingDetailDialog({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('${booking.categoryName} — ${booking.bookingId}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Status', booking.status.replaceAll('_', ' ')),
            _row('Customer', booking.customerId),
            _row('Technician', booking.technicianName),
            _row('Amount', '₹${booking.amount}'),
            _row(
              'Payment',
              booking.paymentStatus.isEmpty ? '—' : booking.paymentStatus,
            ),
            if (booking.complaintStatus.isNotEmpty) ...[
              const Divider(),
              _row('Complaint', booking.complaintStatus),
              _row('Reason', booking.complaintReason.replaceAll('_', ' ')),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Resolve complaints from the Complaints section.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
