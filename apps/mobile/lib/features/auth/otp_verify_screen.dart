import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

/// OTP entry screen. Handles countdown + resend, and pops itself as soon
/// as the auth state flips to authenticated (manual or auto-verification).
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key, required this.phone});

  /// Full number with country code, e.g. +919876543210.
  final String phone;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  static const _resendDelaySeconds = 30;

  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendDelaySeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = _resendDelaySeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) return;

    final auth = context.read<AuthProvider>();
    final error = await auth.verifyOtp(code);
    if (error != null && mounted) {
      _otpController.clear();
      _showMessage(error);
    }
    // On success the AuthGate rebuilds and this route pops via _watchAuth.
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    final auth = context.read<AuthProvider>();
    await auth.resendOtp(
      phone: widget.phone,
      onCodeSent: () {
        if (mounted) {
          _startCountdown();
          _otpController.clear();
          _showMessage('OTP resent. Check your messages.');
        }
      },
      onFailure: (message) => _showMessage(message),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Pops this screen when verification succeeds anywhere (typed OTP or
  /// automatic SMS retriever), revealing the authenticated AuthGate below.
  void _watchAuth(AuthProvider auth) {
    if (auth.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  String get _maskedPhone {
    final digits = widget.phone.replaceAll('+91', '');
    return '${digits.substring(0, 5)} ${digits.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    _watchAuth(auth);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.sms_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter the 6-digit code',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sent to +91 $_maskedPhone',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _otpController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 14,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      hintText: '••••••',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Verify & Continue',
                    busy: auth.busy,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Did not receive the code? ',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_secondsLeft > 0)
                        Text(
                          'Resend in ${_secondsLeft}s',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: auth.busy ? null : _resend,
                          child: const Text('Resend OTP'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
