import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_auth_provider.dart';
import '../shell/admin_shell.dart';
import 'access_denied_screen.dart';
import 'admin_login_screen.dart';

/// Routes the admin panel between login, denied and the shell.
class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthProvider>();

    switch (auth.status) {
      case AdminAuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AdminAuthStatus.signedOut:
        return const AdminLoginScreen();
      case AdminAuthStatus.accessDenied:
        return const AccessDeniedScreen();
      case AdminAuthStatus.authenticated:
        return const AdminShell();
    }
  }
}
