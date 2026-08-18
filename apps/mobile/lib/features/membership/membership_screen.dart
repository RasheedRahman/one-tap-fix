import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/technician_provider.dart';

/// Membership (plan §3.7): subscription plans and the skill-based test
/// (plan §5). Both are recorded server-side by callable functions.
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool _busy = false;

  Future<void> _subscribe(String plan) async {
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(plan == 'monthly' ? 'Monthly plan' : 'Yearly plan'),
        content: Text(
          plan == 'monthly'
              ? '₹499/month with a 10% commission on each job. '
                    'Cancel anytime from the admin panel.'
              : '₹4999/year (12 months) with a 5% commission on each job. '
                    'Best value — cancel anytime from the admin panel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('subscribeTechnician')
          .call({'plan': plan});
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            'Subscribed! ${plan == 'monthly' ? '10%' : '5%'} commission '
            'applies from now on.',
          ),
        ));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e.message ?? 'Could not subscribe.'),
        ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not subscribe.')));
    }
  }

  Future<void> _openSkillTest() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _SkillTestScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      await context.read<TechnicianProvider>().loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tech = context.watch<TechnicianProvider>().profile;
    final scheme = Theme.of(context).colorScheme;
    final subscription = tech?.subscription;
    final skillTest = tech?.skillTest;
    final active = subscription?['status'] == 'active';

    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Plan & commission',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        active
                            ? Icons.verified_user_rounded
                            : Icons.workspace_premium_outlined,
                        color: active ? Colors.green.shade600 : scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        active
                            ? 'Active ${subscription?['plan']} plan'
                            : 'No active plan',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    active
                        ? 'Commission: ${subscription?['commissionPercent']}% '
                              'per job · expires '
                              '${_formatExpiry(subscription?['expiresAt'])}'
                        : 'Subscribe to unlock lower commission rates.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  title: 'Monthly',
                  price: '₹499 / month',
                  commission: '10% commission',
                  onTap: _busy ? null : () => _subscribe('monthly'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlanCard(
                  title: 'Yearly',
                  price: '₹4999 / year',
                  commission: '5% commission',
                  highlighted: true,
                  onTap: _busy ? null : () => _subscribe('yearly'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Skill-based test',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                skillTest?['status'] == 'passed'
                    ? Icons.emoji_events_rounded
                    : Icons.quiz_outlined,
                color: skillTest?['status'] == 'passed'
                    ? Colors.amber.shade700
                    : scheme.primary,
              ),
              title: const Text('MEP skills assessment',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(switch (skillTest?['status']) {
                'passed' => 'Passed '
                    '${skillTest?['score']}/${skillTest?['total']} — '
                    'verified technician.',
                'failed' => 'Attempted, needs 70% to pass. Retry anytime.',
                _ => '10 quick questions to verify your skills (70% to pass).',
              }),
              trailing: FilledButton.tonal(
                onPressed: _openSkillTest,
                child: const Text('Take test'),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static String _formatExpiry(dynamic expiry) {
    if (expiry == null) return '—';
    if (expiry is Timestamp) return expiry.toDate().toLocal().toString().substring(0, 10);
    if (expiry is DateTime) return expiry.toLocal().toString().substring(0, 10);
    return '$expiry';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.commission,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String commission;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlighted ? scheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(price, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                commission,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ten-question quiz. Questions are app-side for now; the callable
/// records the score with a server timestamp (see training.ts).
class _SkillTestScreen extends StatefulWidget {
  const _SkillTestScreen();

  @override
  State<_SkillTestScreen> createState() => _SkillTestScreenState();
}

class _SkillTestScreenState extends State<_SkillTestScreen> {
  static const _questions = [
    ('Which wire colour is live in Indian wiring?', ['Red', 'Green', 'Black', 'Yellow'], 0),
    ('A 2 kW appliance on a 230 V supply draws roughly how many amps?', ['4.3 A', '8.7 A', '12 A', '2 A'], 1),
    ('Water pressure is measured in units of', ['pascal / bar', 'watt', 'amp', 'lux'], 0),
    ('What does the "R" in an RCCB stand for?', ['Residual', 'Rated', 'Rotary', 'Resistance'], 0),
    ('Before touching a drain line, you should', ['Wear gloves and eye protection', 'Pour boiling water in', 'Disconnect the water heater', 'Check the meter'], 0),
    ('The standard Indian wall socket voltage is', ['110 V', '230 V', '380 V', '24 V'], 1),
    ('A thermocouple is commonly used to test', ['Gas appliance flame sensors', 'Water flow', 'Pipe leaks', 'Earthing'], 0),
    ('Which tool measures continuity?', ['Multimeter', 'Spirit level', 'Pipe wrench', 'Hacksaw'], 0),
    ('Emergency isolation for a machine means', ['Cutting its power at the source', 'Unplugging its cord', 'Leaving the site', 'Calling the customer'], 0),
    ('What is the first step before starting any job?', ['Risk assessment', 'Billing the customer', 'Removing the old unit', 'Ordering parts'], 0),
  ];

  int _index = 0;
  final List<int> _answers = [];

  void _pick(int optionIndex) {
    _answers.add(optionIndex);
    if (_index + 1 < _questions.length) {
      setState(() => _index++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final score = List.generate(_questions.length, (i) {
      final (_, _, correct) = _questions[i];
      return _answers[i] == correct ? 1 : 0;
    }).fold<int>(0, (a, b) => a + b);
    final passed = score / _questions.length >= 0.7;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('submitSkillTest')
          .call({'score': score, 'total': _questions.length});
    } catch (_) {}

    if (!mounted) return;
    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(passed ? 'Congratulations!' : 'Not quite there'),
        content: Text(
          passed
              ? 'You scored $score/${_questions.length} — your skill test '
                    'is passed. Customers can now see you as a verified '
                    'technician.'
              : 'You scored $score/${_questions.length}. A score of 70% or '
                    'more is required. You can retake the test anytime.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final (question, options, _) = _questions[_index];
    return Scaffold(
      appBar: AppBar(title: Text('Question ${_index + 1}/${_questions.length}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < options.length; i++) ...[
              OutlinedButton(
                onPressed: () => _pick(i),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(options[i]),
              ),
              const SizedBox(height: 10),
            ],
            const Spacer(),
            Text(
              'You need 70% (${(_questions.length * 0.7).ceil()}+) to pass.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
