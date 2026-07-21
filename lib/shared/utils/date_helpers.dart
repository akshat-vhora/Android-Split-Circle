import 'package:intl/intl.dart';

String formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

String formatDateTime(DateTime date) =>
    DateFormat('dd MMM yyyy, hh:mm a').format(date);

String formatMonth(DateTime date) => DateFormat('MMM yyyy').format(date);

String formatShortMonth(DateTime date) => DateFormat('MMM').format(date);

String timeAgo(DateTime date) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(date.toUtc());

  if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(date);
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime sixMonthsAgo() {
  final now = DateTime.now();
  return DateTime(now.year, now.month - 5, 1);
}

List<DateTime> lastSixMonths() {
  final now = DateTime.now();
  return List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));
}
