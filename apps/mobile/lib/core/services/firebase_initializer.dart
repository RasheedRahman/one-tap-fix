import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Guards Firebase initialization so the app can show a friendly setup
/// screen instead of crashing when firebase_options.dart is still the
/// committed placeholder (see firebase/setup_guide.md).
class FirebaseInitializer {
  FirebaseInitializer._();

  static bool _initialized = false;
  static bool _configured = false;

  /// Returns true when Firebase is ready to use.
  static Future<bool> initialize() async {
    if (_initialized) return _configured;
    _initialized = true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _configured = true;
    } catch (_) {
      _configured = false;
    }
    return _configured;
  }

  static bool get isConfigured => _configured;
}
