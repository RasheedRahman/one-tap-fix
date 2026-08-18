import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/chat_provider.dart';
import 'chat_screen.dart';

/// Opens the job chat screen.
Future<void> openChat(BuildContext context, {required String bookingId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ChatScreen(bookingId: bookingId)),
  );
}

/// Masked call (plan §2.4): asks the server for the other participant's
/// contact (verified participant), then dials it. Numbers never appear
/// in client-readable data.
Future<void> callParticipant(
  BuildContext context, {
  required String bookingId,
  required String label,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: const Text(
        'Your number stays private — MEP Connect verifies you are part of '
        'this job before connecting the call.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final contact = await context.read<ChatProvider>().getContact(bookingId);
  if (!context.mounted) return;
  if (contact == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Contact unavailable.')));
    return;
  }

  final launched = await launchUrl(
    Uri(scheme: 'tel', path: contact.phone),
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not start the call.')));
  }
}

/// Chat + Call row used on both job detail screens.
class ContactButtonsRow extends StatelessWidget {
  const ContactButtonsRow({
    super.key,
    required this.bookingId,
    this.callLabel = 'Call',
  });

  final String bookingId;
  final String callLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => openChat(context, bookingId: bookingId),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Chat'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => callParticipant(
              context,
              bookingId: bookingId,
              label: callLabel,
            ),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: Text(callLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ),
      ],
    );
  }
}
