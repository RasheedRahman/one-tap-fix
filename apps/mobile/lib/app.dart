import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_navigator.dart';
import 'features/auth/auth_gate.dart';
import 'providers/auth_provider.dart';
import 'widgets/firebase_config_screen.dart';

class OneTapFixApp extends StatelessWidget {
  const OneTapFixApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: appNavigatorKey,
      home: firebaseReady ? const AuthGate() : const FirebaseConfigScreen(),
    );
  }
}

/// Convenience wrapper used by tests.
Widget buildApp({
  required bool firebaseReady,
  List<ChangeNotifierProvider>? extraProviders,
}) {
  return MultiProvider(
    providers: [
      if (firebaseReady) ChangeNotifierProvider(create: (_) => AuthProvider()),
      ...?extraProviders,
    ],
    child: OneTapFixApp(firebaseReady: firebaseReady),
  );
}
