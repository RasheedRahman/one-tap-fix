import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/booking_model.dart';
import '../../providers/payment_provider.dart';

/// Where the customer pays for a job (plan §2.6). Two methods:
/// - UPI: opens the platform's UPI intent (`upi://pay`) after the server
///   records an `initiated` payment; the customer confirms on return.
/// - Cash: collected at the doorstep; the customer marks it paid.
///
/// `PASTE_MERCHANT_UPI_ID` is the collection VPA — replace it with the
/// merchant UPI id (see firebase/setup_guide.md). Without it the UPI
/// button explains the app still works with cash.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.booking});

  final BookingModel booking;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  bool _busy = false;

  Future<void> _pay(String method) async {
    final provider = context.read<PaymentProvider>();
    setState(() => _busy = true);
    final error = await provider.initiatePayment(
      bookingId: widget.booking.id,
      method: method,
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (method == 'upi') {
      final ok = await _openUpiIntent();
      if (!ok) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'No UPI app found. Collect via any UPI app or choose cash.',
              ),
            ),
          );
        return;
      }
    }

    final confirmError = await provider.confirmPayment(
      bookingId: widget.booking.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (confirmError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(confirmError)));
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<bool> _openUpiIntent() async {
    const vpa = String.fromEnvironment(
      'MEP_CONNECT_UPI_ID',
      defaultValue: 'PASTE_MERCHANT_UPI_ID',
    );
    if (vpa.startsWith('PASTE_')) return false;

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': vpa,
        'pn': 'MEP Connect',
        'am': '${widget.booking.pricing.estimatedTotal}',
        'tn': widget.booking.invoiceNumber,
        'cu': 'INR',
      },
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = widget.booking.pricing.estimatedTotal;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pay ${widget.booking.invoiceNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ₹$total (minimum charge + service charge + GST)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _option(
              context,
              icon: Icons.qr_code_2_rounded,
              title: 'UPI',
              subtitle: 'Pay via any UPI app (GPay, PhonePe, Paytm)',
              onTap: _busy ? null : () => _pay('upi'),
            ),
            const SizedBox(height: 10),
            _option(
              context,
              icon: Icons.payments_outlined,
              title: 'Cash',
              subtitle: 'Pay at the doorstep when the job is done',
              onTap: _busy ? null : () => _pay('cash'),
            ),
            if (_busy) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
