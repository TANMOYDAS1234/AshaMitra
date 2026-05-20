import 'package:intl/intl.dart';

class DateHelper {
  static String format(DateTime date, [String pattern = 'dd MMM yyyy']) =>
      DateFormat(pattern).format(date);

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
