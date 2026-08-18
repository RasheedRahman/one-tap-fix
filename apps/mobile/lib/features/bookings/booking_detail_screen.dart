import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../../models/booking_model.dart';
import '../../models/complaint_model.dart';
import '../../models/technician_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/booking_status_timeline.dart';
import '../../widgets/rating_stars.dart';
import '../chat/contact_actions.dart';
import '../complaints/complaint_screen.dart';
import '../payments/payment_sheet.dart';
import '../reviews/review_screen.dart';

/// Customer view of a single booking (plan §2.3): live status timeline,
/// assigned technician with skills, and a live tracking map with the
/// technician's location while they are on the way.
class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load the booking.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: Text('Booking not found.'));
          }
          final booking = BookingModel.fromJson(bookingId, data);
          return _BookingDetailBody(booking: booking);
        },
      ),
    );
  }
}

class _BookingDetailBody extends StatelessWidget {
  const _BookingDetailBody({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusBanner(status: booking.status),
        const SizedBox(height: 14),
        BookingStatusTimeline(status: booking.status),
        const SizedBox(height: 14),
        if (booking.technicianId != null) ...[
          _TechnicianCard(booking: booking),
          const SizedBox(height: 12),
        ],
        if (booking.technicianId != null) ...[
          _LiveTrackCard(booking: booking),
          const SizedBox(height: 12),
          ContactButtonsRow(
            bookingId: booking.id,
            callLabel: 'Call technician',
          ),
          const SizedBox(height: 12),
        ] else
          _WaitingCard(status: booking.status),
        if (booking.status == BookingStatus.completed) ...[
          _ReviewSection(booking: booking),
          const SizedBox(height: 12),
        ],
        if (booking.needsPayment) ...[
          _PaymentCard(booking: booking),
          const SizedBox(height: 12),
        ],
        if (booking.canFileComplaint) ...[
          _ComplaintCard(booking: booking),
          const SizedBox(height: 12),
        ],
        if (booking.complaintStatus.isNotEmpty) ...[
          _ComplaintStatusCard(booking: booking),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        _DetailsCard(booking: booking),
        if (booking.canCancelByCustomer) ...[
          const SizedBox(height: 16),
          _CancelButton(booking: booking),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final icon = switch (status) {
      BookingStatus.completed => Icons.check_circle_rounded,
      BookingStatus.cancelled || BookingStatus.refunded => Icons.cancel_rounded,
      BookingStatus.inProgress ||
      BookingStatus.enRoute => Icons.engineering_rounded,
      BookingStatus.accepted => Icons.handshake_rounded,
      _ => Icons.radar_rounded,
    };
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Icon(icon, color: scheme.onPrimaryContainer, size: 30),
        title: Text(
          BookingStatus.label(status),
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          status == BookingStatus.pending || status == BookingStatus.matching
              ? 'We are looking for the nearest technician.'
              : 'Updated just now',
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cancelled =
        status == BookingStatus.cancelled || status == BookingStatus.refunded;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!cancelled) ...[
              const CircularProgressIndicator(strokeWidth: 2.5),
              const SizedBox(height: 12),
            ],
            Text(
              cancelled
                  ? 'This booking was cancelled.'
                  : 'Looking for a technician…',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (!cancelled) ...[
              const SizedBox(height: 4),
              Text(
                'You will be notified the moment one accepts.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final name = booking.technicianName;
    final rating =
        (booking.technicianInfo?['rating'] as num?)?.toDouble() ?? 0.0;

    // Skill badges come from the live technicians/{uid} doc; names are
    // looked up in the service catalog.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('technicians')
          .doc(booking.technicianId)
          .snapshots(),
      builder: (context, snapshot) {
        final tech = snapshot.data?.data() == null
            ? null
            : TechnicianModel.fromJson(
                booking.technicianId!,
                snapshot.data!.data()!,
              );
        final skills = tech?.skills ?? const <String>[];
        final catalog = context.read<CatalogProvider>();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.person_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              RatingStars(rating: rating),
                              const SizedBox(width: 6),
                              Text(
                                rating == 0
                                    ? 'New technician'
                                    : rating.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (tech?.isAvailable ?? false) const _LiveChip(),
                  ],
                ),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Skills',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in skills)
                        Chip(
                          label: Text(
                            catalog.byId(skill)?.name ?? skill,
                            style: theme.textTheme.labelSmall,
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: scheme.tertiary),
          const SizedBox(width: 4),
          Text(
            'Live',
            style: TextStyle(
              color: scheme.onTertiaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Embedded Google Map with the customer's pin and a marker that follows
/// the technician's live location, plus a live distance/ETA banner.
class _LiveTrackCard extends StatefulWidget {
  const _LiveTrackCard({required this.booking});

  final BookingModel booking;

  @override
  State<_LiveTrackCard> createState() => _LiveTrackCardState();
}

class _LiveTrackCardState extends State<_LiveTrackCard> {
  GoogleMapController? _mapController;
  bool _followTechnician = true;
  LatLng? _lastCentered;

  LatLng get _destination => LatLng(
    widget.booking.location.latitude,
    widget.booking.location.longitude,
  );

  void _maybeCenterOn(LatLng position) {
    final controller = _mapController;
    final last = _lastCentered;
    if (controller == null || !_followTechnician) return;
    // Only re-center when the technician has moved meaningfully.
    if (last != null &&
        (position.latitude - last.latitude).abs() < 0.003 &&
        (position.longitude - last.longitude).abs() < 0.003) {
      return;
    }
    _lastCentered = position;
    controller.animateCamera(CameraUpdate.newLatLng(position));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('technicians')
                .doc(widget.booking.technicianId)
                .snapshots(),
            builder: (context, snapshot) {
              final tech = snapshot.data?.data() == null
                  ? null
                  : TechnicianModel.fromJson(
                      widget.booking.technicianId!,
                      snapshot.data!.data()!,
                    );
              final location = tech?.currentLocation;
              final position = location == null
                  ? null
                  : LatLng(location.latitude, location.longitude);

              final distanceKm = position == null
                  ? null
                  : Geo.haversineKm(
                      position.latitude,
                      position.longitude,
                      _destination.latitude,
                      _destination.longitude,
                    );

              final markers = <Marker>{
                Marker(
                  markerId: const MarkerId('destination'),
                  position: _destination,
                  infoWindow: InfoWindow(title: widget.booking.bookingId),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
                if (position != null)
                  Marker(
                    markerId: const MarkerId('technician'),
                    position: position,
                    infoWindow: const InfoWindow(title: 'Your technician'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                  ),
              };

              return Column(
                children: [
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _destination,
                            zoom: 14,
                          ),
                          markers: markers,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            if (position != null) _maybeCenterOn(position);
                          },
                          onCameraIdle: () {
                            // User panned away — stop auto-following.
                            _followTechnician = false;
                          },
                        ),
                        if (position != null)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: FloatingActionButton.small(
                              heroTag: 'recenter-${widget.booking.id}',
                              tooltip: 'Re-centre map',
                              onPressed: () {
                                setState(() => _followTechnician = true);
                                _maybeCenterOn(position);
                              },
                              child: const Icon(Icons.my_location_rounded),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.navigation_rounded,
                          color: scheme.tertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            position == null
                                ? 'Waiting for the technician to share '
                                      'their live location…'
                                : distanceKm! < 0.05
                                ? 'Technician has arrived at your location.'
                                : 'Technician is ${distanceKm.toStringAsFixed(1)} km away'
                                      ' · ~${Geo.etaMinutesForKm(distanceKm)} min',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .doc(booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final rated = data == null ? null : (data['rating'] as num?)?.toInt();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  rated == null
                      ? Icons.star_outline_rounded
                      : Icons.star_rounded,
                  color: rated == null ? scheme.outline : scheme.tertiary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rated == null
                            ? 'How was the service?'
                            : 'You rated $rated star${rated == 1 ? '' : 's'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rated == null
                            ? 'Your review helps other customers pick '
                                  'the right technician.'
                            : 'Thanks for your feedback.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (rated == null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReviewScreen(
                          bookingId: booking.id,
                          technicianId: booking.technicianId!,
                          technicianName: booking.technicianName,
                        ),
                      ),
                    ),
                    child: const Text('Rate'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = booking.pricing.estimatedTotal;

    // Live payment record (server-owned) so the card flips to "paid"
    // as soon as `confirmPayment` lands.
    return StreamBuilder<Map<String, dynamic>?>(
      stream: context.read<PaymentProvider>().streamPayment(booking.id),
      builder: (context, snapshot) {
        final paid =
            snapshot.data?['status'] == 'succeeded' ||
            booking.paymentStatus == 'paid';
        final method =
            (snapshot.data?['method'] as String?) ?? booking.paymentMethod;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  paid ? Icons.check_circle_rounded : Icons.payments_outlined,
                  color: paid ? Colors.green.shade600 : scheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paid
                            ? 'Paid ₹$total${method.isEmpty ? '' : ' via $method'}'
                            : 'Pay ₹$total',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        paid
                            ? 'Thanks! Your payment is recorded.'
                            : 'UPI or cash — settle with your technician.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!paid)
                  FilledButton(
                    onPressed: () => showModalBottomSheet<bool>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => PaymentSheet(booking: booking),
                    ),
                    child: const Text('Pay'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.report_problem_outlined, color: scheme.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not happy with the service?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'File a complaint — paid jobs flagged as not done '
                    'properly are auto-refunded.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ComplaintScreen(bookingId: booking.id),
                ),
              ),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintStatusCard extends StatelessWidget {
  const _ComplaintStatusCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final refunded = booking.status == BookingStatus.refunded;

    return Card(
      color: refunded ? scheme.tertiaryContainer : null,
      child: ListTile(
        leading: Icon(
          refunded
              ? Icons.currency_rupee_rounded
              : Icons.report_problem_outlined,
          color: refunded ? scheme.onTertiaryContainer : scheme.error,
        ),
        title: Text(
          refunded ? 'Refunded' : 'Complaint under review',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          refunded
              ? 'The paid amount has been reversed for this job.'
              : '${ComplaintReasons.label(booking.complaintReason)} — '
                    'our team will get back to you.',
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pricing = booking.pricing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.categoryName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (booking.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                booking.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (booking.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final url in booking.mediaUrls)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 76,
                          height: 76,
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: scheme.outline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _row(
              context,
              Icons.schedule_rounded,
              booking.isEmergency
                  ? 'ASAP (emergency)'
                  : shortDateTime(booking.scheduledAt),
            ),
            const SizedBox(height: 4),
            _row(context, Icons.location_on_outlined, booking.location.address),
            if (booking.etaMinutes != null) ...[
              const SizedBox(height: 4),
              _row(
                context,
                Icons.speed_rounded,
                'ETA ~${booking.etaMinutes} min (when accepted)',
              ),
            ],
            const Divider(height: 24),
            Text(
              'Price estimate',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _row(
              context,
              Icons.currency_rupee_rounded,
              'Min. charge ${inr(pricing.minCharge)} + service '
              '${inr(pricing.serviceCharge)}',
            ),
            const SizedBox(height: 4),
            _row(
              context,
              Icons.percent_rounded,
              'GST ${pricing.gstPercent}% (${inr(pricing.gstAmount)})',
            ),
            const SizedBox(height: 4),
            _row(
              context,
              Icons.receipt_long_rounded,
              'Estimated total ${inr(pricing.estimatedTotal)}',
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String text, {
    bool emphasized = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.booking});

  final BookingModel booking;

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          'Booking ${booking.bookingId} will be cancelled. '
          '${booking.isEmergency ? 'This was an emergency request.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await context.read<BookingProvider>().cancelBooking(booking);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => _cancel(context),
      icon: const Icon(Icons.cancel_outlined, size: 18),
      label: const Text('Cancel booking'),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}
