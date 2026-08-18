import 'package:flutter/material.dart';

import '../models/booking_model.dart';

/// Horizontal stepper for the job lifecycle:
/// Finding → Accepted → En Route → On Site → Done.
class BookingStatusTimeline extends StatelessWidget {
  const BookingStatusTimeline({super.key, required this.status});

  final String status;

  static const _stages = [
    (icon: Icons.radar_rounded, label: 'Finding'),
    (icon: Icons.verified_rounded, label: 'Accepted'),
    (icon: Icons.navigation_rounded, label: 'En route'),
    (icon: Icons.build_rounded, label: 'On site'),
    (icon: Icons.flag_rounded, label: 'Done'),
  ];

  bool get _cancelled =>
      status == BookingStatus.cancelled || status == BookingStatus.refunded;

  int get _reached => switch (status) {
    BookingStatus.matching => 1,
    BookingStatus.accepted => 2,
    BookingStatus.enRoute => 3,
    BookingStatus.inProgress => 4,
    BookingStatus.completed => 5,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reached = _cancelled ? 0 : _reached;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _stages.length; i++) ...[
          _Stage(
            icon: _stages[i].icon,
            label: _stages[i].label,
            active: i < reached,
            current: i == reached - 1,
            cancelled: _cancelled,
          ),
          if (i < _stages.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 13),
                color: i < reached - 1
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.icon,
    required this.label,
    required this.active,
    required this.current,
    required this.cancelled,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool current;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = cancelled
        ? scheme.outline
        : active
        ? (current ? scheme.primary : scheme.primary.withValues(alpha: 0.55))
        : scheme.outlineVariant;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
