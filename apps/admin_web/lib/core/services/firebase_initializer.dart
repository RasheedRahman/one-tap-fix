import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Guards Firebase initialization so the admin panel shows a friendly
/// setup screen instead of crashing on the placeholder config.
class FirebaseInitializer {
  FirebaseInitializer._();

  static bool _initialized = false;
  static bool _configured = false;

  static Future<bool> initialize() async {
    if (_initialized) return _configured;
    _initialized = true;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      _configured = true;
    } catch (_) {
      _configured = false;
    }
    return _configured;
  }

  static bool get isConfigured => _configured;
}
