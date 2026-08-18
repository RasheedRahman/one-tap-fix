import 'package:intl/intl.dart';

/// Indian Rupee formatting, e.g. ₹1,234.
String inr(num value) => '₹${NumberFormat('#,##0').format(value)}';

/// Short date, e.g. 12 Aug 2026.
String shortDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

/// Short date + time, e.g. 12 Aug 2026, 10:00 AM.
String shortDateTime(DateTime date) =>
    DateFormat('d MMM yyyy, h:mm a').format(date);

/// Short time, e.g. 10:00 AM.
String shortTime(DateTime date) => DateFormat('h:mm a').format(date);
