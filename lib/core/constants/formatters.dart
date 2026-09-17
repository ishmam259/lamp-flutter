import 'package:intl/intl.dart';

class LaMPFormatters {
  static const String tk = '৳ ';

  /// Bangladeshi / Indian lakh and crore grouping (12,34,567)
  static String formatBDT(num amount) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    final formatted = formatter.format(amount.round());
    return '$tk$formatted';
  }

  static String formatBDTPlain(num amount) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return formatter.format(amount.round());
  }

  static String formatBDTCompact(num amount) {
    final abs = amount.abs();
    if (abs >= 10000000) {
      return '$tk${(amount / 10000000).toStringAsFixed(2)} cr';
    }
    if (abs >= 100000) {
      return '$tk${(amount / 100000).toStringAsFixed(2)} L';
    }
    if (abs >= 1000) {
      return '$tk${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '$tk${amount.round()}';
  }

  static String formatPct(num value, [int dp = 0]) {
    return '${value.toStringAsFixed(dp)}%';
  }

  static String formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String formatDateShort(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateFormat('dd MMM').format(dt);
  }

  static String formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateFormat('HH:mm:ss').format(dt);
  }

  static String formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateFormat('dd MMM yyyy HH:mm:ss').format(dt);
  }

  static String formatDaysUntil(int targetMs, int fromMs) {
    final days = ((targetMs - fromMs) / 86400000).ceil();
    if (days == 0) return 'due today';
    if (days == 1) return 'due tomorrow';
    if (days > 0) return 'in $days days';
    if (days == -1) return '1 day overdue';
    return '${days.abs()} days overdue';
  }

  static String formatDuration(int ms) {
    if (ms <= 0) return '0s';
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String shortHash(String hash, {int head = 8, int tail = 6}) {
    if (hash.length <= head + tail + 1) return hash;
    return '${hash.substring(0, head)}…${hash.substring(hash.length - tail)}';
  }
}
