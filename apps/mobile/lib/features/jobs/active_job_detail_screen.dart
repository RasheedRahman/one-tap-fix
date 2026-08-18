import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/maps_launcher.dart';
import '../../models/booking_model.dart';
import '../../providers/technician_provider.dart';
import '../../widgets/booking_status_timeline.dart';
import '../chat/contact_actions.dart';

/// Technician view of an in-flight job (plan §3.2/§3.4): customer info,
/// one-tap navigation, and the on-site flow buttons
/// (Start Trip → Start Service → Complete).
class ActiveJobDetailScreen extends StatelessWidget {
  const ActiveJobDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load the job.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: Text('Job not found.'));
          }
          final booking = BookingModel.fromJson(bookingId, data);
          return _JobDetailBody(booking: booking);
        },
      ),
    );
  }
}

class _JobDetailBody extends StatefulWidget {
  const _JobDetailBody({required this.booking});

  final BookingModel booking;

  @override
  State<_JobDetailBody> createState() => _JobDetailBodyState();
}

class _JobDetailBodyState extends State<_JobDetailBody> {
  bool _busy = false;

  BookingModel get booking => widget.booking;

  Future<void> _runJobAction(String action) async {
    final actionLabel = switch (action) {
      JobActions.startTrip => 'Start trip',
      JobActions.startService => 'Start service',
      JobActions.complete => 'Complete job',
      _ => 'Continue',
    };

    if (action == JobActions.complete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete this job?'),
          content: const Text(
            'Marking the job complete lets the customer rate you and '
            'releases your earnings for settlement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Complete job'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    final error = await context.read<TechnicianProvider>().updateJobStatus(
      booking.id,
      action,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$actionLabel — done')));
  }

  Future<void> _cancelJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this job?'),
        content: const Text(
          'The customer will be notified. A cancelled job counts against '
          'your reliability stats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep job'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel job'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final error = await context.read<TechnicianProvider>().cancelJob(
      booking.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _navigate() async {
    final opened = await MapsLauncher.openNavigation(
      latitude: booking.location.latitude,
      longitude: booking.location.longitude,
      label: 'Customer location',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the maps app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nextAction = booking.nextTechnicianAction;
    final canCancel =
        booking.status == BookingStatus.accepted ||
        booking.status == BookingStatus.enRoute;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusBanner(status: booking.status),
        const SizedBox(height: 14),
        BookingStatusTimeline(status: booking.status),
        const SizedBox(height: 14),
        _CustomerCard(booking: booking),
        const SizedBox(height: 12),
        ContactButtonsRow(bookingId: booking.id, callLabel: 'Call customer'),
        const SizedBox(height: 12),
        _DistanceCard(booking: booking),
        const SizedBox(height: 12),
        _JobDetailsCard(booking: booking),
        if (nextAction != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : () => _runJobAction(nextAction),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_actionLabel(nextAction)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
        if (nextAction == null && !canCancel) ...[
          const SizedBox(height: 16),
          const Center(child: Text('This job is finished.')),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _navigate,
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Navigate to customer'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (canCancel) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : _cancelJob,
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Cancel this job'),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  static String _actionLabel(String action) => switch (action) {
    JobActions.startTrip => 'Start trip',
    JobActions.startService => 'Start service',
    JobActions.complete => 'Complete job',
    _ => action,
  };
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          status == BookingStatus.enRoute
              ? Icons.navigation_rounded
              : Icons.engineering_rounded,
          color: scheme.onPrimaryContainer,
          size: 30,
        ),
        title: Text(
          BookingStatus.label(status),
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(switch (status) {
          BookingStatus.accepted => 'Start your trip when you are ready.',
          BookingStatus.enRoute => 'Let the customer know when you arrive.',
          BookingStatus.inProgress => 'Complete the job when you are done.',
          _ => 'Updated just now',
        }, style: TextStyle(color: scheme.onPrimaryContainer)),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(booking.customerId)
          .snapshots(),
      builder: (context, snapshot) {
        final name = snapshot.data?.data()?['name'] as String? ?? 'Customer';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: scheme.secondaryContainer,
                      child: Icon(
                        Icons.person_rounded,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          Text(
                            'Customer · ${booking.bookingId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = context.watch<TechnicianProvider>();
    final distanceKm = provider.distanceKmTo(
      booking.location.latitude,
      booking.location.longitude,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.speed_rounded, color: scheme.tertiary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                distanceKm == null
                    ? 'Enable availability to share your live distance.'
                    : 'You are ${distanceKm.toStringAsFixed(1)} km away'
                          ' · ~${Geo.etaMinutesForKm(distanceKm)} min drive',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobDetailsCard extends StatelessWidget {
  const _JobDetailsCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
            const SizedBox(height: 12),
            _row(context, Icons.location_on_outlined, booking.location.address),
            const SizedBox(height: 4),
            _row(
              context,
              Icons.schedule_rounded,
              booking.isEmergency
                  ? 'ASAP (emergency)'
                  : shortDateTime(booking.scheduledAt),
            ),
            const SizedBox(height: 4),
            _row(
              context,
              Icons.currency_rupee_rounded,
              'Est. ${inr(booking.pricing.estimatedTotal)}'
              ' · GST ${booking.pricing.gstPercent}% included',
            ),
            if (booking.etaMinutes != null) ...[
              const SizedBox(height: 4),
              _row(
                context,
                Icons.speed_rounded,
                'ETA ~${booking.etaMinutes} min (at acceptance)',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
