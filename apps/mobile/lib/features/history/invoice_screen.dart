import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/booking_model.dart';

/// Invoice for a completed (or historical) service (plan §5).
/// The invoice is a read-only presentation of the immutable pricing
/// snapshot stored on the booking; the number is derived from the
/// booking's short id, so it is stable without server-side documents.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key, required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pricing = booking.pricing;

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'MEP CONNECT',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.invoiceNumber,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${BookingStatus.label(booking.status)} — '
                    '${shortDate(booking.invoiceDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 12),
                  _row(theme, 'Service', booking.categoryName),
                  _row(theme, 'Booked on', shortDate(booking.createdAt)),
                  if (booking.completedAt != null)
                    _row(
                      theme,
                      'Completed on',
                      shortDate(booking.completedAt!),
                    ),
                  _row(theme, 'Booking ref', booking.bookingId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Technician',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row(theme, 'Name', booking.technicianName),
                  _row(
                    theme,
                    'Phone',
                    booking.technicianInfo?['phone'] as String? ?? '—',
                  ),
                  _row(
                    theme,
                    'Rating',
                    booking.technicianInfo?['rating'] == null
                        ? '—'
                        : (booking.technicianInfo!['rating'] as num)
                              .toStringAsFixed(1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Charges',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row(theme, 'Minimum charge', '₹${pricing.minCharge}'),
                  _row(theme, 'Service charge', '₹${pricing.serviceCharge}'),
                  const Divider(height: 20),
                  _row(theme, 'Subtotal', '₹${pricing.baseTotal}', bold: true),
                  _row(
                    theme,
                    'GST (${pricing.gstPercent}%)',
                    '₹${pricing.gstAmount}',
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '₹${pricing.estimatedTotal}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.status == BookingStatus.completed
                          ? 'Payment collected at the doorstep '
                                '(UPI / cash — online payments arrive with '
                                'the payments feature).'
                          : 'This service was not completed; no amount is due.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(
    ThemeData theme,
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w700 : null,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
