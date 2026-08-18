import 'dart:async';

import 'package:flutter/foundation.dart';

/// Lightweight in-app event bus used for cross-shell navigation
/// (e.g. "notification tapped → open the Jobs tab").
class AppEvents extends ChangeNotifier {
  static const String openTechnicianJobs = 'open_technician_jobs';
  static const String openCustomerBookings = 'open_customer_bookings';

  final _controller = StreamController<String>.broadcast(sync: true);

  Stream<String> get stream => _controller.stream;

  void publish(String event) => _controller.add(event);

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
