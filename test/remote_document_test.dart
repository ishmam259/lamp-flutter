import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/remote/lamp_api.dart';
import 'package:lamp_flutter/core/state/lamp_state.dart';

/// On the shared ledger the invoice PDF steps go to the server.
///
/// The server mints invoices itself, so it cannot know the PDF's hash: the
/// manufacturer's phone issues it, and the bank's check is recorded there too.
/// Both used to write to the phone's own ledger even in shared mode, where
/// nobody else could see them.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(LaMPState, List<Map<String, dynamic>>)> sharedState() async {
    final fixture = File('test/fixtures/mobile_state_sample.json').readAsStringSync();
    final posted = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        posted.add(Map<String, dynamic>.from(jsonDecode(req.body) as Map));
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      if (req.url.path.endsWith('/height')) {
        return http.Response(jsonEncode({'height': 1}), 200);
      }
      return http.Response.bytes(utf8.encode(fixture), 200);
    });
    final state = LaMPState(api: LampApi('https://lamp.test', client: client));
    await state.initWorld();
    return (state, posted);
  }

  test('the manufacturer issues the PDF to the server once', () async {
    final (state, posted) = await sharedState();
    final res = await state.issueInvoicePdf('RCV-00235', 'a' * 64);
    expect(res?.ok, isTrue);
    expect(posted.single['action'], 'issueDocument');
    expect(posted.single['args'], {'tokenId': 'RCV-00235', 'sha256': 'a' * 64});
  });

  test('the bank records its check on the server', () async {
    final (state, posted) = await sharedState();
    final res = await state.anchorInvoiceDocument(
      'RCV-00235',
      Msp.meghnaMSP,
      sha256: 'a' * 64,
      byteLength: 6914,
      filename: 'inv-00235.pdf',
    );
    expect(res.ok, isTrue);
    expect(posted.single['action'], 'anchor');
    expect(posted.single['args']['bank'], 'MeghnaMSP');
  });

  test('on the phone\'s own ledger issuing is a no-op: it happened at mint',
      () async {
    final state = LaMPState(api: null);
    expect(state.isRemote, isFalse);
    expect(await state.issueInvoicePdf('RCV-00235', 'a' * 64), isNull);
  });
}
