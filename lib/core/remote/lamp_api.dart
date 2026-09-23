import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/domain_models.dart';
import '../models/ledger_models.dart';

/// The shared ledger's server: the LaMP web app's `/api/mobile/*` routes.
///
/// Configured at build time, so a build either talks to a server or runs its
/// own on-phone ledger — never a mix:
///
/// ```bash
/// flutter build apk --dart-define=LAMP_API_URL=https://lamp-opal-chi.vercel.app
/// ```
///
/// `LAMP_DEV_SECRET` unlocks the server's clock and reset controls, which a
/// public deployment keeps locked; it only matters for testing builds.
class LampApi {
  static const String _configuredUrl = String.fromEnvironment('LAMP_API_URL');
  static const String _devSecret = String.fromEnvironment('LAMP_DEV_SECRET');

  /// The configured server, or null to run the on-phone ledger.
  static LampApi? configured() =>
      _configuredUrl.isEmpty ? null : LampApi(_configuredUrl);

  final String baseUrl;
  final http.Client _http;

  LampApi(String baseUrl, {http.Client? client})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _http = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 20);

  /// Everything the phone renders, in one read.
  Future<RemoteState> state() async {
    final res = await _http
        .get(Uri.parse('$baseUrl/api/mobile/state'))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw LampApiException('The server answered ${res.statusCode}.');
    }
    return RemoteState.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map),
    );
  }

  /// The ledger's height, polled to know when to read [state]. The server
  /// answers it from a small row of its own, so polling does not pull the
  /// ledger out of its database each time.
  Future<int> height() async {
    final res = await _http
        .get(Uri.parse('$baseUrl/api/mobile/height'))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw LampApiException('The server answered ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map;
    return (body['height'] as num).toInt();
  }

  /// One write. The server answers `{ok, error?, tx?}` for ledger writes.
  Future<RemoteResult> act(
    String action,
    Map<String, dynamic> args, {
    bool demoControl = false,
  }) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl/api/mobile/action'),
          headers: {
            'content-type': 'application/json',
            if (demoControl && _devSecret.isNotEmpty) 'x-lamp-dev-secret': _devSecret,
          },
          body: jsonEncode({'action': action, 'args': args}),
        )
        .timeout(_timeout);
    final body = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map,
    );
    final tx = body['tx'];
    return RemoteResult(
      ok: body['ok'] == true,
      error: body['error'] as String?,
      tx: tx is Map ? ChainTx.fromJson(Map<String, dynamic>.from(tx)) : null,
    );
  }
}

class LampApiException implements Exception {
  final String message;
  LampApiException(this.message);
  @override
  String toString() => message;
}

class RemoteResult {
  final bool ok;
  final String? error;
  final ChainTx? tx;
  const RemoteResult({required this.ok, this.error, this.tx});
}

/// The server's ledger and off-ledger world, parsed into the phone's models.
class RemoteState {
  final int height;
  final int now;
  final Map<String, dynamic> world;
  final List<ChainTx> txs;
  final List<Invoice> invoices;
  final List<Delivery> deliveries;

  const RemoteState({
    required this.height,
    required this.now,
    required this.world,
    required this.txs,
    required this.invoices,
    required this.deliveries,
  });

  factory RemoteState.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(String key) => [
          for (final e in (json[key] as List<dynamic>? ?? const []))
            Map<String, dynamic>.from(e as Map),
        ];
    return RemoteState(
      height: (json['height'] as num).toInt(),
      now: (json['now'] as num).toInt(),
      world: Map<String, dynamic>.from(json['world'] as Map),
      txs: maps('txs').map(ChainTx.fromJson).toList(),
      invoices: maps('invoices').map(Invoice.fromJson).toList(),
      deliveries: maps('deliveries').map(Delivery.fromJson).toList(),
    );
  }
}
