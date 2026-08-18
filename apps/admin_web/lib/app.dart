import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/admin_auth_gate.dart';
import 'widgets/firebase_config_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: firebaseReady
          ? const AdminAuthGate()
          : const FirebaseConfigScreen(),
    );
  }
}
