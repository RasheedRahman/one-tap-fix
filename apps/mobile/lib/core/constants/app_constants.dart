import 'package:flutter/material.dart';

/// Global app constants. Everything user-facing lives here so the
/// multi-language feature (ta/kn/hi/en) can centralize later.
class AppConstants {
  AppConstants._();

  static const String appName = 'MEP Connect';
  static const String tagline = '1 Tap Service';

  /// Brand color used to seed the Material 3 ColorScheme.
  static const Color brandSeedColor = Color(0xFF0D6EFD);

  /// Color reserved for the emergency-service flow.
  static const Color emergencyColor = Color(0xFFDC2626);

  /// Default locale until the multi-language feature ships.
  static const String defaultLocale = 'en';

  /// Languages planned by implementation_plan.docx (multi-language feature).
  static const List<String> supportedLocales = ['en', 'ta', 'kn', 'hi'];
}

/// Role constants mirroring the `users.role` field in Firestore.
class AppRoles {
  AppRoles._();

  static const String customer = 'customer';
  static const String technician = 'technician';
  static const String admin = 'admin';

  static const List<String> mobileSelectable = [customer, technician];
}
