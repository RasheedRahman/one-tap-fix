import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../../../providers/technician_provider.dart';

/// A live matching offer with one-tap Accept / Decline (plan §3.3).
class JobOfferCard extends StatefulWidget {
  const JobOfferCard({super.key, required this.booking});

  final BookingModel booking;

  @override
  State<JobOfferCard> createState() => _JobOfferCardState();
}

class _JobOfferCardState extends State<JobOfferCard> {
  bool _busy = false;

  Future<void> _act(
    Future<String?> Function(String bookingId) action,
    String successNote,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await action(widget.booking.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successNote)));
    }
  }

  String? _distanceLabel(BookingModel booking) {
    final tech = context.read<TechnicianProvider>();
    final km = tech.distanceKmTo(
      booking.location.latitude,
      booking.location.longitude,
    );
    if (km == null) return null;
    return '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final booking = widget.booking;
    final distance = _distanceLabel(booking);

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.bookingId,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Spacer(),
                if (booking.isEmergency)
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: scheme.error),
                      const SizedBox(width: 2),
                      Text(
                        'Emergency',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              booking.categoryName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (booking.description.isNotEmpty &&
                booking.description != 'Emergency service request') ...[
              const SizedBox(height: 4),
              Text(
                booking.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            _infoRow(
              Icons.location_on_outlined,
              booking.location.address,
            ),
            const SizedBox(height: 4),
            _infoRow(
              Icons.schedule_rounded,
              booking.isEmergency
                  ? 'ASAP (emergency)'
                  : shortDateTime(booking.scheduledAt),
            ),
            const SizedBox(height: 4),
            _infoRow(
              Icons.currency_rupee_rounded,
              'Est. ${inr(booking.pricing.estimatedTotal)}',
              bold: true,
            ),
            if (distance != null) ...[
              const SizedBox(height: 4),
              _infoRow(Icons.near_me_rounded, distance),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _act(
                              (id) =>
                                  context.read<TechnicianProvider>().acceptJob(id),
                              'Job accepted! See it under Active.',
                            ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Accept Job'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _act(
                              (id) =>
                                  context.read<TechnicianProvider>().rejectJob(id),
                              'Job declined.',
                            ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {bool bold = false}) {
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: bold ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: bold ? FontWeight.w700 : null,
                ),
          ),
        ),
      ],
    );
  }
}
