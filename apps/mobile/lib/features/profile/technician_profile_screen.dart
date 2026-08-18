import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/review_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/technician_provider.dart';
import '../../widgets/rating_stars.dart';
import '../membership/membership_screen.dart';
import '../reviews/review_card.dart';
import '../training/training_screen.dart';

/// Technician profile: identity, skills/experience, rating summary and
/// the reviews customers left on completed jobs.
class TechnicianProfileScreen extends StatelessWidget {
  const TechnicianProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final tech = context.watch<TechnicianProvider>().profile;
    final uid = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Icon(Icons.handyman_rounded, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      user?.phone ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileStats(tech: tech),
          const SizedBox(height: 16),
          Text(
            'Customer reviews',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (uid.isEmpty)
            const SizedBox.shrink()
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('technicianId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load reviews.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final reviews = snapshot.data!.docs
                    .map((d) => ReviewModel.fromJson(d.id, d.data()))
                    .toList();
                if (reviews.isEmpty) {
                  return const _NoReviews();
                }
                return Column(
                  children: [
                    for (final review in reviews) ...[
                      ReviewCard(review: review),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Membership & skill test'),
                  subtitle: const Text('Plans, commission and verification'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MembershipScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.play_circle_outline_rounded),
                  title: const Text('Training & safety videos'),
                  subtitle: const Text('Learn new skills and stay safe'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TrainingScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({required this.tech});

  final dynamic tech;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final skills = (tech?.skills as List?) ?? const <String>[];
    final rating = (tech?.rating as num?)?.toDouble() ?? 0.0;
    final ratingsCount = (tech?.ratingsCount as num?)?.toInt() ?? 0;
    final completed = (tech?.completedJobs as num?)?.toInt() ?? 0;
    final experience = (tech?.experienceYears as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RatingStars(rating: rating),
                const SizedBox(width: 8),
                Text(
                  rating == 0
                      ? 'No ratings yet'
                      : '${rating.toStringAsFixed(1)} '
                            '($ratingsCount review${ratingsCount == 1 ? '' : 's'})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statRow(
              context,
              Icons.work_outline_rounded,
              '$completed job${completed == 1 ? '' : 's'} completed',
            ),
            const SizedBox(height: 4),
            _statRow(
              context,
              Icons.school_outlined,
              '$experience year${experience == 1 ? '' : 's'} experience',
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 10),
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
                  for (final skill in skills.cast<String>())
                    Chip(
                      label: Text(skill, style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.outline),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NoReviews extends StatelessWidget {
  const _NoReviews();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              'No reviews yet. Reviews appear here after customers '
              'complete jobs with you.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
