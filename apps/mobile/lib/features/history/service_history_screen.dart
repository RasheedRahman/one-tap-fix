import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../bookings/booking_detail_screen.dart';
import 'invoice_screen.dart';

/// Customer service history (plan §5): past bookings with their invoices
/// and the technician who served them.
class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  String _filter = BookingStatus.completed;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Service history')),
      body: uid.isEmpty
          ? const SizedBox.shrink()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('customerId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load history.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bookings = snapshot.data!.docs
                    .map((d) => BookingModel.fromJson(d.id, d.data()))
                    .where((b) => b.status == _filter)
                    .toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: BookingStatus.completed,
                            label: Text('Completed'),
                          ),
                          ButtonSegment(
                            value: BookingStatus.cancelled,
                            label: Text('Cancelled'),
                          ),
                          ButtonSegment(
                            value: BookingStatus.refunded,
                            label: Text('Refunded'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (selection) =>
                            setState(() => _filter = selection.first),
                      ),
                    ),
                    Expanded(
                      child: bookings.isEmpty
                          ? _EmptyState(filter: _filter)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: bookings.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final booking = bookings[index];
                                return _HistoryCard(
                                  booking: booking,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          InvoiceScreen(booking: booking),
                                    ),
                                  ),
                                  onDetails: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => BookingDetailScreen(
                                        bookingId: booking.id,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.booking,
    required this.onTap,
    required this.onDetails,
  });

  final BookingModel booking;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.secondaryContainer,
                    child: Icon(
                      Icons.build_rounded,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.categoryName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          shortDate(booking.invoiceDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      BookingStatus.label(booking.status),
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: switch (booking.status) {
                      BookingStatus.completed => scheme.secondaryContainer,
                      BookingStatus.refunded => scheme.tertiaryContainer,
                      _ => scheme.surfaceContainerHighest,
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.handyman_outlined,
                    size: 15,
                    color: scheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.technicianName,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${booking.pricing.estimatedTotal}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Invoice'),
                  ),
                  TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = switch (filter) {
      BookingStatus.cancelled => 'No cancelled bookings yet.',
      BookingStatus.refunded => 'No refunded bookings yet.',
      _ =>
        'No completed services yet. When a job is done, '
            'you will find its invoice here.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 44, color: scheme.outline),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
