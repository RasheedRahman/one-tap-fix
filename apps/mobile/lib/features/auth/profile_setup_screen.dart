import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import 'technician_skills_screen.dart';

/// Collects the display name after role selection and writes the
/// `users/{uid}` profile document (onboarding completion).
/// Profile photo upload ships with the profile feature.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.role});

  final String role;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool get _isTechnician => widget.role == AppRoles.technician;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    // Technicians continue to the skills/experience step first; the
    // users/{uid} doc is written there after createProfile succeeds.
    if (widget.role == AppRoles.technician) {
      final name = _nameController.text.trim();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TechnicianSkillsScreen(name: name),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.completeProfile(
      role: widget.role,
      name: _nameController.text,
    );

    if (error != null && mounted) {
      _showError(error);
      return;
    }
    // On success the AuthGate below rebuilds and routes to the right shell;
    // pop this route so the user lands on the shell directly.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isTechnician ? 'Technician profile' : 'Customer profile'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        _isTechnician
                            ? Icons.handyman_rounded
                            : Icons.person_rounded,
                        size: 42,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      label: Text(
                        _isTechnician ? 'Technician account' : 'Customer account',
                      ),
                      side: BorderSide(color: scheme.primary),
                      backgroundColor: scheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      autofocus: true,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.length < 2) {
                          return 'Enter your full name';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _finish(),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: _isTechnician
                          ? 'Finish & open dashboard'
                          : 'Finish & continue',
                      icon: Icons.check_rounded,
                      busy: auth.busy,
                      onPressed: _finish,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'By continuing you confirm your details are correct. '
                      'Your role cannot be changed later.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
