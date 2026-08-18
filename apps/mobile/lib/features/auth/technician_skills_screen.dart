import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/service_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/technician_provider.dart';
import '../../widgets/primary_button.dart';

/// Technician onboarding step 2 (after name): skills (which service
/// categories this technician works in) + years of experience.
/// These fields feed the matching engine and cannot be changed later
/// (rules protect them; edits come via admin later).
class TechnicianSkillsScreen extends StatefulWidget {
  const TechnicianSkillsScreen({super.key, required this.name});

  final String name;

  @override
  State<TechnicianSkillsScreen> createState() => _TechnicianSkillsScreenState();
}

class _TechnicianSkillsScreenState extends State<TechnicianSkillsScreen> {
  final Set<String> _selectedSkills = {};
  int _experienceYears = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().load();
    });
  }

  Future<void> _finish() async {
    if (_selectedSkills.isEmpty) {
      _showError('Select at least one skill.');
      return;
    }
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final technician = context.read<TechnicianProvider>();

    final profileError = await technician.createProfile(
      skills: _selectedSkills.toList()..sort(),
      experienceYears: _experienceYears,
    );
    if (profileError != null) {
      setState(() => _submitting = false);
      _showError(profileError);
      return;
    }

    // users/{uid} doc with the role — marks onboarding complete.
    final userError = await auth.completeProfile(
      role: 'technician',
      name: widget.name,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (userError != null) {
      _showError(userError);
      return;
    }

    // AuthGate below rebuilds into TechnicianShell; pop this route.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalog = context.watch<CatalogProvider>();
    final services = catalog.services ?? const <ServiceModel>[];
    final busy = _submitting ||
        context.watch<TechnicianProvider>().busy ||
        context.watch<AuthProvider>().busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Your skills')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'What services do you offer?',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'The matching system sends you jobs only for the skills '
                  'you select. This cannot be changed later.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (catalog.loading && services.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final service in services)
                        FilterChip(
                          avatar: Icon(
                            ServiceIcons.forKey(service.iconKey),
                            size: 18,
                          ),
                          label: Text(service.name),
                          selected: _selectedSkills.contains(service.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedSkills.add(service.id);
                            } else {
                              _selectedSkills.remove(service.id);
                            }
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text(
                  'Years of experience',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _experienceYears,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.workspace_premium_outlined),
                  ),
                  items: [
                    for (var i = 1; i <= 30; i++)
                      DropdownMenuItem(value: i, child: Text('$i ${i == 1 ? 'year' : 'years'}')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _experienceYears = value);
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Finish setup',
                  icon: Icons.check_rounded,
                  busy: busy,
                  onPressed: busy ? null : _finish,
                ),
                const SizedBox(height: 12),
                Text(
                  'You can start accepting jobs after setup. KYC approval '
                  'is managed by the admin panel.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
