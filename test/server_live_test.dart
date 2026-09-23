import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamp_flutter/core/constants/ledger_labels.dart';
import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/remote/lamp_api.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';
import 'package:lamp_flutter/core/world/queries.dart';

/// Two phones, one ledger — against a real server.
///
/// Opt-in: set `LAMP_TEST_SERVER` to a LaMP web app whose demo controls are
/// open (a local `next dev`, never the public deployment — this resets the
/// world):
///
/// ```bash
/// LAMP_TEST_SERVER=http://localhost:3000 flutter test test/server_live_test.dart
/// ```
void main() {
  final server = Platform.environment['LAMP_TEST_SERVER'];

  Future<void> until(bool Function() ok, {int seconds = 20}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!ok()) {
      if (DateTime.now().isAfter(end)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  test('a scan on one phone reaches another; the server refuses what the chaincode refuses',
      () async {
    final officer = LaMPState(api: LampApi(server!));
    final bank = LaMPState(api: LampApi(server));
    addTearDown(officer.dispose);
    addTearDown(bank.dispose);
    await until(() => officer.isInitialized && bank.isInitialized);

    await officer.resetWorld();
    await until(() => officer.viewFor('RCV-00235')?.token.state == TokenState.created);
    final carton = officer.viewFor('RCV-00235')!.delivery!.cartons.first;

    final scan = await officer.scanCarton('RCV-00235', carton.gs1, 'LMP-DEV-4471');
    expect(scan.ok, isTrue, reason: scan.error);
    expect(officer.viewFor('RCV-00235')!.token.scanned, 1);
    expect(officer.getDelivery('RCV-00235')!.cartons.first.scannedAt, isNotNull);

    // The other phone sees it at its next poll.
    await until(() => bank.viewFor('RCV-00235')?.token.scanned == 1, seconds: 25);

    final foreign = await officer.scanCarton(
      'RCV-00235',
      '(01)08901234001019(17)280824(10)BCH-FOREIGN(21)SN-9999',
      'LMP-DEV-4471',
    );
    expect(foreign.ok, isFalse);
    expect(LedgerLabels.reason(foreign.error), "This carton isn't part of this invoice.");

    final early = await officer.confirmDelivery('RCV-00235', 'stroke');
    expect(early.ok, isFalse, reason: 'signed for goods that were never scanned');
  }, skip: server == null ? 'set LAMP_TEST_SERVER to run against a server' : false,
      timeout: const Timeout(Duration(minutes: 3)));
}
