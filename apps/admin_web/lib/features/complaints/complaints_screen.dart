import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/admin_api.dart';
import '../../models/complaint_model.dart';

/// Complaint resolution (plan §4.2): review submissions and either
/// resolve with a note or issue a refund on paid jobs.
class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load complaints.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final complaints = snapshot.data!.docs
            .map((d) => ComplaintModel.fromJson(d.id, d.data()))
            .toList();
        if (complaints.isEmpty) {
          return const Center(child: Text('No complaints yet.'));
        }
        return ListView.separated(
          itemCount: complaints.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final complaint = complaints[index];
            return _ComplaintTile(complaint: complaint);
          },
        );
      },
    );
  }
}

class _ComplaintTile extends StatelessWidget {
  const _ComplaintTile({required this.complaint});

  final ComplaintModel complaint;

  Future<void> _resolve(BuildContext context) async {
    final controller = TextEditingController();
    var refund = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Resolve ${complaint.bookingId.substring(0, 8)}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ComplaintModel.reasonLabel(complaint.reason),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (complaint.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(complaint.description),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Resolution note',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Issue a refund (paid jobs only)'),
                  value: refund,
                  onChanged: (v) => setState(() => refund = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Resolve'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final error = await AdminApi.resolveComplaint(
      bookingId: complaint.bookingId,
      resolution: controller.text.trim().isEmpty
          ? 'Resolved by admin'
          : controller.text.trim(),
      refund: refund,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'Complaint resolved'),
          backgroundColor: error == null ? Colors.green : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = complaint.status == 'resolved';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: resolved
            ? scheme.tertiaryContainer
            : scheme.errorContainer,
        child: Icon(
          resolved ? Icons.done_rounded : Icons.assignment_late_rounded,
        ),
      ),
      title: Text(
        '${complaint.bookingId.substring(0, 8)} · '
        '${ComplaintModel.reasonLabel(complaint.reason)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        complaint.description.isEmpty
            ? (resolved
                  ? 'Resolved: ${complaint.resolution}'
                  : 'No description')
            : complaint.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(complaint.status),
            visualDensity: VisualDensity.compact,
          ),
          if (!resolved) ...[
            const SizedBox(width: 6),
            FilledButton.tonal(
              onPressed: () => _resolve(context),
              child: const Text('Resolve'),
            ),
          ],
        ],
      ),
    );
  }
}
