import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/firebase_initializer.dart';
import 'providers/app_events.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/complaint_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/spare_parts_provider.dart';
import 'providers/technician_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await FirebaseInitializer.initialize();

  runApp(
    MultiProvider(
      providers: [
        if (firebaseReady) ...[
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CatalogProvider()),
          ChangeNotifierProvider(create: (_) => BookingProvider()),
          ChangeNotifierProvider(create: (_) => TechnicianProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => PaymentProvider()),
          ChangeNotifierProvider(create: (_) => ComplaintProvider()),
          ChangeNotifierProvider(create: (_) => SparePartsProvider()),
          ChangeNotifierProvider(create: (_) => AppEvents()),
        ],
      ],
      child: OneTapFixApp(firebaseReady: firebaseReady),
    ),
  );
}
