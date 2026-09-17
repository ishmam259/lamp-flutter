# LaMP — Flutter client

A Flutter application for **LaMP (Last Mile Pharmacy)**, a consortium blockchain
settlement layer for pharmaceutical supply chain finance. Prototype for BCOLBD 2026.

Five seats over one ledger: the two field applications (MPO, pharmacy) and the
three institutional portals (manufacturer, bank, regulator).

## Running it

```bash
flutter pub get
flutter run                 # phone or emulator
flutter run -d chrome       # browser
flutter build web --release # static bundle in build/web
```

The web build is self-contained — the ledger runs inside the app, so there is no
server or database to deploy. `build/web` can be hosted as static files.

## How it is built

```
lib/
  core/
    chain/      contract.dart   the state machine
                ledger.dart     hash-chained ledger, private data collections
                policy.dart     endorsement policy parser + evaluator
                crypto.dart     sha256 + canonical stringify
    world/      seed.dart       the deterministic seeded world
                clock.dart      the demo clock
                gs1.dart        GS1 element strings for carton identity
    models/     domain + ledger types
    state/      LaMPState — one ChangeNotifier over the whole world
  features/     launcher · mpo · pharmacy · manufacturer · bank · regulator
  widgets/      lifecycle rail · private seal · credit ring · recourse dial
                signature pad · data matrix · ledger inspector · demo director
```

`core/chain/contract.dart` holds the seven chaincode functions from whitepaper
§4.2 — `mintReceivable`, `recordPoD`, `recordPoDBatch`, `registerRateCurve`,
`matchAndAdvance`, `settle`, and the dispute pair. The endorsement policy strings
shown in the UI are the strings that actually gate the writes, so a policy failure
on screen is a genuine failure rather than an animation.

## Relationship to the Next.js application

This is a **separate implementation**, not a client of the web app. The original
`lib/chain/contract.ts` in the Next.js repo *is* the Fabric chaincode — the same
file is compiled into the chaincode package, so the two cannot drift. This Dart
port is a second implementation and **can** drift. Treat the TypeScript as
authoritative where they disagree.

### Known divergences

Token ids (`RCV-00235`) and both rate curves now match the TypeScript seed, so
Meghna wins the deterministic match at **80% advance / 8.8% fee** on a BUILDING
counterparty with the same band values on both sides.

One difference remains, deliberately: the GS1 payload here is written in the
human-readable form `(01)…(17)…(10)…(21)…`, where the TypeScript emits the true
element string with FNC1 separators. Both hash consistently within their own
application, but a physically printed GS1 DataMatrix would decode to the
TypeScript form and be refused by this app. Worth closing before anything is
printed on a real carton.

## Carton scanning

Two paths, and the field app offers whichever the platform supports.

**Camera** (Android and iOS) reads the code through `mobile_scanner` and submits
the decoded payload to `recordPoD` untouched — never a hash, and never checked
against the manifest first — so a carton from another invoice is refused by the
chaincode's own membership test rather than by the UI deciding in advance.

**On-screen cascade** is the fallback, and what web and desktop builds use. It
walks the consignment at demo pace and still routes every carton through the
same chaincode call, including the planted misrouted carton at position 14.

Tapping a carton's code in the scanner list enlarges it into something a second
device can read. Those codes are QR, not DataMatrix, carrying the identical GS1
payload: encoding ECC200 is several hundred lines of Reed-Solomon that would
prove nothing extra, and the caption on screen says which symbology it is.

## Persistence

The world is stored as one JSON document under a single SharedPreferences key —
localStorage on web, a plist or XML file on the phones. Ledger, clock and the
off-chain records are only meaningful together, so one key makes a half-written
world unrepresentable.

Saves are debounced 400 ms and hang off `notifyListeners`, so a new action
cannot be added that silently fails to persist. A stored world that will not
load is discarded and reseeded rather than blocking startup. **Reset world** in
the demo director clears the store and rebuilds the seeded world.

## Status

`flutter analyze` is clean and `flutter test` passes 11/11 — policy parsing
(AND/OR/OutOf/nested), world seeding, carton-hash rejection, the
Building→Established tier upgrade on the eighth settled cycle, and three
persistence tests covering the snapshot round trip through `jsonEncode`,
private-data membership surviving a restore, and a restored ledger continuing
its hash chain from the stored tip rather than from genesis.

## Notes

- Company names are fictional. Real manufacturer or bank branding in a live
  financing interface would imply participation that does not exist.
- Money is grouped the Bangladeshi way — 12,34,567 rather than 1,234,567.
