// LaMP Demo Clock
// Provides simulated ledger time with fixed initial epoch (24 Aug 2026, 09:00 Dhaka)
// and real-time ticking between clock jumps.

class DemoClock {
  // 24 Aug 2026, 03:00 UTC / 09:00 Dhaka
  static const int demoEpoch = 1787454000000;

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
}
