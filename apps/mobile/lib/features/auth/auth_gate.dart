import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../shell/customer_shell.dart';
import '../shell/technician_shell.dart';
import 'account_blocked_screen.dart';
import 'admin_not_allowed_screen.dart';
import 'auth_error_screen.dart';
import 'phone_login_screen.dart';
import 'role_select_screen.dart';
import 'splash_screen.dart';

/// The single decision point for navigation in the mobile app.
/// Every rebuild re-evaluates auth state and routes the user to the
/// right experience (CustomerShell / TechnicianShell / onboarding).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();

      case AuthStatus.unauthenticated:
        return const PhoneLoginScreen();

      case AuthStatus.authenticated:
        final user = auth.user;

        // Signed in but the profile could not be loaded.
        if (user == null && auth.authError != null) {
          return AuthErrorScreen(error: auth.authError!);
        }

        // First sign-in: no profile doc yet -> pick a role.
        if (user == null || !user.onboardingCompleted) {
          return const RoleSelectScreen();
        }

        if (user.isBlocked) {
          return const AccountBlockedScreen();
        }

        switch (user.role) {
          case AppRoles.customer:
            return const CustomerShell();
          case AppRoles.technician:
            return const TechnicianShell();
          default:
            // Admin accounts belong to the web panel.
            return const AdminNotAllowedScreen();
        }
    }
  }
}
