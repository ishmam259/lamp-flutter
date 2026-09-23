import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lamp_flutter/core/chain/ledger.dart';
import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/models/ledger_models.dart';
import 'package:lamp_flutter/core/remote/lamp_api.dart';
import 'package:lamp_flutter/core/world/queries.dart';

/// The phone parses what the server sends.
///
/// `fixtures/mobile_state_sample.json` is a trimmed response from the LaMP
/// web app's `GET /api/mobile/state` — real server output, not a hand-written
/// imitation — so a drift between the two codebases' models fails here
/// rather than on a phone.
void main() {
  late RemoteState state;

  setUpAll(() {
    final raw = File('test/fixtures/mobile_state_sample.json').readAsStringSync();
    state = RemoteState.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  });

  test('the whole response parses', () {
    expect(state.height, greaterThan(0));
    expect(state.txs, isNotEmpty);
    expect(state.invoices, isNotEmpty);
    expect(state.deliveries, isNotEmpty);
    expect(state.deliveries.first.cartons, isNotEmpty);
  });

  test('world entries parse into the phone\'s models', () {
    for (final entry in state.world.entries) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      if (entry.key.startsWith('token:')) {
        final token = ReceivableToken.fromJson(value);
        expect(entry.key, 'token:${token.tokenId}');
      } else if (entry.key.startsWith('credit:')) {
        final credit = CreditHistory.fromJson(value);
        expect(entry.key, 'credit:${credit.pharmacyDid}');
      }
    }
  });

  test('records keep ledger order, statuses and private writes', () {
    final numbers = state.txs.map((t) => t.blockNumber).toList();
    expect(numbers, [...numbers]..sort());
    expect(state.txs.any((t) => t.status == TxStatus.chaincodeError), isTrue);
    expect(state.txs.any((t) => t.privateWrites.isNotEmpty), isTrue);
  });

  test('a mirrored ledger answers the same queries as a local one', () {
    final ledger = LocalLedger()
      ..mirror(world: state.world, txs: state.txs, height: state.height);

    expect(ledger.height, state.height);
    expect(ledger.txs.length, state.txs.length);

    final views = LaMPQueries.listTokenViews(
      ledger,
      state.invoices,
      state.deliveries,
    );
    final hero = views.firstWhere((v) => v.tokenId == 'RCV-00235');
    expect(hero.invoice?.invoiceId, 'INV-00235');
    expect(hero.delivery, isNotNull);
  });
}
