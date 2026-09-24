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

  /// Bangladesh Standard Time, UTC+6. No DST to account for.
  ///
  /// Ledger time is an absolute instant; where it is *read* is Dhaka. These
  /// formatters rendered in UTC, so every date and time on every screen ran
  /// six hours early — and anything after 18:00 local showed the day before.
  /// The TypeScript pins `Asia/Dhaka` for the same reason (`format.ts:46-53`).
  static const Duration _dhakaOffset = Duration(hours: 6);

  static DateTime _dhaka(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(_dhakaOffset);

  static String formatDate(int ms) => DateFormat('dd MMM yyyy').format(_dhaka(ms));

  static String formatDateShort(int ms) => DateFormat('dd MMM').format(_dhaka(ms));

  static String formatTime(int ms) => DateFormat('HH:mm:ss').format(_dhaka(ms));

  /// `09:00` — a time of day for people, without seconds.
  static String formatClock(int ms) => DateFormat('HH:mm').format(_dhaka(ms));

  static String formatDateTime(int ms) =>
      DateFormat('dd MMM yyyy HH:mm:ss').format(_dhaka(ms));

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
