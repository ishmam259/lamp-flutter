import 'package:flutter_test/flutter_test.dart';
import 'package:lamp_flutter/core/world/clock.dart';

/// Ledger time for a new world starts at [DemoClock.startOfWorld]: the fixed
/// demo date in tests, the real date in the app. A world seeded on 30 Sep
/// used to open on 24 Aug, a month behind the phone.
void main() {
  tearDown(() => DemoClock.startOfWorld = () => DemoClock.demoEpoch);

  test('a new world starts where startOfWorld says', () {
    final today = DateTime.utc(2026, 9, 30, 8).millisecondsSinceEpoch;
    DemoClock.startOfWorld = () => today;
    final clock = DemoClock()..reset();
    expect(clock.now - today, inInclusiveRange(0, 1000));
  });

  test('the start survives a save and restore', () {
    final today = DateTime.utc(2026, 9, 30, 8).millisecondsSinceEpoch;
    DemoClock.startOfWorld = () => today;
    final clock = DemoClock()..reset();
    clock.advanceHours(5);

    final restored = DemoClock()..restore(clock.toJson());
    expect((restored.now - clock.now).abs(), lessThan(1000));
  });

  test('a world saved before the start was stored keeps the demo date', () {
    DemoClock.startOfWorld = () => DateTime.now().millisecondsSinceEpoch;
    final restored = DemoClock()
      ..restore({'offset': 0, 'anchor': DateTime.now().millisecondsSinceEpoch});
    expect(restored.now - DemoClock.demoEpoch, inInclusiveRange(0, 1000));
  });

  test('syncing to a server adopts its time', () {
    final clock = DemoClock()..reset();
    final serverNow = DemoClock.demoEpoch + 3 * 86400000;
    clock.syncTo(serverNow);
    expect((clock.now - serverNow).abs(), lessThan(1000));
  });
}
