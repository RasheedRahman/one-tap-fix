import 'package:firebase_messaging/firebase_messaging.dart';

import '../../features/chat/chat_screen.dart';
import '../../providers/app_events.dart';
import '../../providers/auth_provider.dart';
import '../utils/app_navigator.dart';

/// Firebase Cloud Messaging wiring:
/// - permission + token retrieval/refresh → saved to `users/{uid}.fcmToken`
/// - foreground messages / taps → AppEvents so shells can react
///
/// Call once after sign-in (both shells call it; idempotent).
class FcmService {
  FcmService._();

  static bool _initialized = false;

  static Future<void> initialize(AuthProvider auth, AppEvents events) async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final token = await messaging.getToken();
      if (token != null) await auth.saveFcmToken(token);

      messaging.onTokenRefresh.listen((t) => auth.saveFcmToken(t));
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
      FirebaseMessaging.onMessage.listen((m) => _handle(m, events));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _handle(m, events));

      final initial = await messaging.getInitialMessage();
      if (initial != null) _handle(initial, events);
    } catch (_) {
      // Unavailable on some platforms (e.g. iOS simulator, no APNs).
    }
  }

  static void _handle(RemoteMessage message, AppEvents events) {
    final type = message.data['type'];
    switch (type) {
      case 'new_job':
        events.publish(AppEvents.openTechnicianJobs);
      case 'booking_accepted' ||
          'job_status' ||
          'booking_completed' ||
          'booking_cancelled':
        events.publish(AppEvents.openCustomerBookings);
      case 'chat_message':
        // Jump straight into the job chat from the notification.
        final chatId = message.data['chatId'] ?? message.data['bookingId'];
        if (chatId != null && chatId.isNotEmpty) {
          AppNavigator.push(ChatScreen(bookingId: chatId));
        }
    }
  }
}

/// Runs in the background isolate; must be a top-level function.
/// Job offers are read from Firestore streams when the app resumes,
/// so no work is needed here beyond keeping the handler registered.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {}
