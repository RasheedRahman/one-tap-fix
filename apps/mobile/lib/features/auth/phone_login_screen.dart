import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/primary_button.dart';
import 'email_login_screen.dart';
import 'otp_verify_screen.dart';

/// Primary entry screen. Phone OTP is the main login for customers and
/// technicians; email is the fallback (and the admin panel's login).
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final phone = '+91${_phoneController.text.trim()}';

    await auth.sendOtp(
      phone: phone,
      onCodeSent: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(phone: phone),
          ),
        );
      },
      onFailure: (message) => _showError(message),
    );
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
    final auth = context.watch<AuthProvider>();

    return Scaffold(
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
                    const AppLogo(),
                    const SizedBox(height: 36),
                    Text(
                      'Login with your mobile number',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We will send a one-time password to verify your number.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixText: '+91  ',
                        hintText: '98765 43210',
                        counterText: '',
                      ),
                      validator: (value) {
                        final digits = value?.trim() ?? '';
                        if (digits.length != 10) {
                          return 'Enter a valid 10-digit mobile number';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _continue(),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      busy: auth.busy,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: auth.busy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EmailLoginScreen(),
                                ),
                              ),
                      icon: const Icon(Icons.mail_outline_rounded, size: 20),
                      label: const Text('Login with Email instead'),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'By continuing you agree to our Terms of Service and '
                      'Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
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
