import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../active_job_detail_screen.dart';

/// Compact card for active/completed/cancelled technician jobs.
/// Shows the customer's name (fetched from users/{customerId}) and
/// opens the full job screen (on-site flow) on tap.
class TechnicianJobCard extends StatelessWidget {
  const TechnicianJobCard({super.key, required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActiveJobDetailScreen(bookingId: booking.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    booking.bookingId,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(status: booking.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                booking.categoryName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _CustomerName(customerId: booking.customerId),
              const SizedBox(height: 4),
              _infoRow(
                context,
                Icons.location_on_outlined,
                booking.location.address,
              ),
              const SizedBox(height: 4),
              _infoRow(
                context,
                Icons.schedule_rounded,
                booking.isEmergency
                    ? 'ASAP (emergency)'
                    : shortDateTime(booking.scheduledAt),
              ),
              const SizedBox(height: 4),
              _infoRow(
                context,
                Icons.currency_rupee_rounded,
                'Est. ${inr(booking.pricing.estimatedTotal)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _CustomerName extends StatelessWidget {
  const _CustomerName({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get(),
      builder: (context, snapshot) {
        final name = snapshot.data?.data()?['name'] as String? ?? 'Customer';
        return Row(
          children: [
            Icon(Icons.person_outline_rounded, size: 16, color: scheme.outline),
            const SizedBox(width: 6),
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      BookingStatus.completed => scheme.primary,
      BookingStatus.cancelled || BookingStatus.refunded => scheme.outline,
      _ => scheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        BookingStatus.label(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
