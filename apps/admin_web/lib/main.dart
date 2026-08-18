import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/firebase_initializer.dart';
import 'providers/admin_auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await FirebaseInitializer.initialize();

  runApp(
    MultiProvider(
      providers: [
        if (firebaseReady)
          ChangeNotifierProvider(create: (_) => AdminAuthProvider()),
      ],
      child: AdminApp(firebaseReady: firebaseReady),
    ),
  );
}
