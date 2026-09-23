// LaMP Demo Clock
// Provides simulated ledger time with fixed initial epoch (24 Aug 2026, 09:00 Dhaka)
// and real-time ticking between clock jumps.

class DemoClock {
  /// 24 Aug 2026, 03:00 UTC / 09:00 Dhaka.
  ///
  /// `Date.UTC(2026, 7, 24, 3, 0, 0)` in the TypeScript clock. The constant
  /// here was 1787454000000, which is a day earlier than the comment beside
  /// it claimed.
  static const int demoEpoch = 1787540400000;

  int _offset = 0;
  int _anchor = DateTime.now().millisecondsSinceEpoch;

  int get offset => _offset;

  int get now => demoEpoch + _offset + (DateTime.now().millisecondsSinceEpoch - _anchor);

  int advance(int ms) {
    if (ms < 0) throw ArgumentError('The demo clock does not run backwards');
    _offset += ms;
    return now;
  }

  int advanceHours(int hours) => advance(hours * 3600 * 1000);

  int advanceDays(int days) => advance(days * 86400 * 1000);

  void reset() {
    _offset = 0;
    _anchor = DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> toJson() => {'offset': _offset, 'anchor': _anchor};

  /// Restore a persisted clock.
  ///
  /// The anchor is restored rather than re-taken, so real time that passed
  /// while the app was closed still counts. Re-anchoring to now would freeze
  /// ledger time whenever the app is not running, and two transactions either
  /// side of a restart would carry a smaller gap than actually elapsed.
  /// Adopt a server's ledger time, so what this phone stamps and what the
  /// server records are the same moment.
  void syncTo(int serverNow) {
    _anchor = DateTime.now().millisecondsSinceEpoch;
    _offset = serverNow - demoEpoch;
  }

  void restore(Map<String, dynamic> json) {
    _offset = (json['offset'] as num?)?.toInt() ?? 0;
    _anchor = (json['anchor'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
  }
}
