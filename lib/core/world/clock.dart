// LaMP ledger clock.
//
// Ledger time starts at a world's creation and runs in real time from there;
// the testing tools can move it forward (`advance`), never back.
//
// Where it starts is [DemoClock.startOfWorld]. Tests leave that at the fixed
// demo date (24 Aug 2026, 09:00 Dhaka) so every date they assert is
// reproducible. The app sets it to the real date in `main()`: a world seeded
// on 30 Sep used to open on 24 Aug, so "due in 34 days" was counted from a
// month ago and every timestamp on screen was a month behind the phone.

class DemoClock {
  /// 24 Aug 2026, 03:00 UTC / 09:00 Dhaka.
  ///
  /// `Date.UTC(2026, 7, 24, 3, 0, 0)` in the TypeScript clock. The constant
  /// here was 1787454000000, which is a day earlier than the comment beside
  /// it claimed.
  static const int demoEpoch = 1787540400000;

  /// Where a new world's ledger time starts. See the file comment.
  static int Function() startOfWorld = () => demoEpoch;

  int _epoch = demoEpoch;
  int _offset = 0;
  int _anchor = DateTime.now().millisecondsSinceEpoch;

  int get offset => _offset;

  int get now => _epoch + _offset + (DateTime.now().millisecondsSinceEpoch - _anchor);

  int advance(int ms) {
    if (ms < 0) throw ArgumentError('The demo clock does not run backwards');
    _offset += ms;
    return now;
  }

  int advanceHours(int hours) => advance(hours * 3600 * 1000);

  int advanceDays(int days) => advance(days * 86400 * 1000);

  /// Start over, for a new world.
  void reset() {
    _epoch = startOfWorld();
    _offset = 0;
    _anchor = DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> toJson() => {'epoch': _epoch, 'offset': _offset, 'anchor': _anchor};

  /// Adopt a server's ledger time, so what this phone stamps and what the
  /// server records are the same moment.
  void syncTo(int serverNow) {
    _anchor = DateTime.now().millisecondsSinceEpoch;
    _offset = serverNow - _epoch;
  }

  /// Restore a persisted clock.
  ///
  /// The anchor is restored rather than re-taken, so real time that passed
  /// while the app was closed still counts. Re-anchoring to now would freeze
  /// ledger time whenever the app is not running, and two transactions either
  /// side of a restart would carry a smaller gap than actually elapsed.
  ///
  /// A world saved before the epoch was stored began at [demoEpoch], and
  /// keeps it: moving its start would move every record already on it.
  void restore(Map<String, dynamic> json) {
    _epoch = (json['epoch'] as num?)?.toInt() ?? demoEpoch;
    _offset = (json['offset'] as num?)?.toInt() ?? 0;
    _anchor = (json['anchor'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
  }
}
