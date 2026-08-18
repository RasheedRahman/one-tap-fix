import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/admin_api.dart';
import '../../models/technician_model.dart';
import '../../models/user_model.dart';

/// User management (plan §4.1): verify technician KYC, block/unblock
/// accounts, and send password-reset emails.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _technicians = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Technicians')),
            ButtonSegment(value: false, label: Text('Customers')),
          ],
          selected: {_technicians},
          onSelectionChanged: (s) => setState(() => _technicians = s.first),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _technicians
              ? const _TechniciansList()
              : const _CustomersList(),
        ),
      ],
    );
  }
}

class _TechniciansList extends StatelessWidget {
  const _TechniciansList();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('technicians')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load technicians.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('users').limit(500).snapshots(),
          builder: (context, usersSnap) {
            final names = <String, UserModel>{};
            for (final d
                in usersSnap.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
              final m = UserModel.fromJson(d.id, d.data());
              names[d.id] = m;
            }
            final rows = docs.map((d) {
              final tech = TechnicianModel.fromJson(d.id, d.data());
              final user = names[d.id];
              return (tech: tech, user: user);
            }).toList();
            if (rows.isEmpty) {
              return const Center(child: Text('No technicians yet.'));
            }
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = rows[index];
                return _TechnicianTile(tech: row.tech, user: row.user);
              },
            );
          },
        );
      },
    );
  }
}

class _TechnicianTile extends StatefulWidget {
  const _TechnicianTile({required this.tech, required this.user});

  final TechnicianModel tech;
  final UserModel? user;

  @override
  State<_TechnicianTile> createState() => _TechnicianTileState();
}

class _TechnicianTileState extends State<_TechnicianTile> {
  bool _busy = false;

  Future<void> _setKyc(String status) async {
    setState(() => _busy = true);
    final error = await AdminApi.approveKyc(widget.tech.uid, status);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'KYC $status'),
          backgroundColor: error == null ? Colors.green : null,
        ),
      );
  }

  Future<void> _cancelSubscription() async {
    final tech = widget.tech;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: Text(
          '${tech.name.isEmpty ? tech.uid : tech.name} will lose the '
          '${tech.subscription?['commissionPercent']}% commission rate and '
          'fall back to the standard rate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final error = await AdminApi.cancelSubscription(tech.uid);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'Subscription cancelled'),
          backgroundColor: error == null ? Colors.green : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tech = widget.tech;
    final kycColor = switch (tech.kycStatus) {
      'approved' => scheme.tertiaryContainer,
      'rejected' => scheme.errorContainer,
      _ => scheme.surfaceContainerHighest,
    };

    return ListTile(
      leading: CircleAvatar(
        child: Text(tech.name.isEmpty ? '?' : tech.name[0].toUpperCase()),
      ),
      title: Text(
        tech.name.isEmpty
            ? 'Technician ${tech.uid.substring(0, 8)}'
            : tech.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${tech.phone.isEmpty ? tech.uid : tech.phone} · '
        '★ ${tech.rating.toStringAsFixed(1)} (${tech.ratingsCount}) · '
        '${tech.completedJobs} jobs · '
        '${tech.completionRate.round()}% completion · '
        'balance ₹${tech.balance}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tech.subscriptionLabel.isNotEmpty) ...[
            Chip(
              label: Text('Plan ${tech.subscriptionLabel}'),
              visualDensity: VisualDensity.compact,
              backgroundColor: scheme.tertiaryContainer,
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Cancel subscription',
              onPressed: _busy ? null : _cancelSubscription,
              icon: const Icon(Icons.workspace_premium_outlined),
            ),
          ],
          if (tech.skillTest?['status'] == 'passed') ...[
            const SizedBox(width: 6),
            Chip(
              label: const Text('Verified'),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.green.shade50,
            ),
          ],
          const SizedBox(width: 6),
          Chip(
            label: Text('KYC ${tech.kycStatus}'),
            visualDensity: VisualDensity.compact,
            backgroundColor: kycColor,
          ),
          if (tech.kycStatus != 'approved') ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Approve KYC',
              onPressed: _busy ? null : () => _setKyc('approved'),
              icon: const Icon(Icons.verified_outlined, color: Colors.green),
            ),
          ],
          if (tech.kycStatus == 'approved') ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Reject KYC',
              onPressed: _busy ? null : () => _setKyc('rejected'),
              icon: const Icon(Icons.gpp_bad_outlined, color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomersList extends StatelessWidget {
  const _CustomersList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load customers.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No customers yet.'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = UserModel.fromJson(docs[index].id, docs[index].data());
            return _CustomerTile(user: user);
          },
        );
      },
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.user});

  final UserModel user;

  Future<void> _resetPassword(BuildContext context) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('This customer has no email — use phone login.'),
          ),
        );
      return;
    }
    final error = await AdminApi.resetPassword(email);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'Password reset email sent to $email'),
          backgroundColor: error == null ? Colors.green : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase()),
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${user.phone ?? user.uid} · ${user.email ?? 'no email'}'),
      trailing: IconButton(
        tooltip: 'Send password reset',
        onPressed: () => _resetPassword(context),
        icon: const Icon(Icons.password_rounded),
      ),
    );
  }
}
