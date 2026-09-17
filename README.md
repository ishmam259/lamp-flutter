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

| | Dart | TypeScript |
| --- | --- | --- |
| Hero token id | `tok-00235` | `RCV-00235` |
| Meghna NEW band | 70% / 10.5% / 60% recourse | 70% / 9.5% / 100% recourse |

The number the demo turns on is intact: Meghna wins the deterministic match at
**80% advance / 8.8% fee** on a BUILDING counterparty, beating Padma's 75% / 9.4%.

## Status

`flutter analyze` is clean and `flutter test` passes 8/8 — policy parsing
(AND/OR/OutOf/nested), world seeding, carton-hash rejection, and the
Building→Established tier upgrade on the eighth settled cycle.

Not yet built:

- **Camera scanning.** The carton scanner is the simulated cascade. Wiring
  `mobile_scanner` to decode real GS1 DataMatrix codes is the outstanding piece.
- **Persistence.** `LaMPState` builds a fresh in-memory ledger on every launch,
  so closing the app resets the world to its seeded state.

## Notes

- Company names are fictional. Real manufacturer or bank branding in a live
  financing interface would imply participation that does not exist.
- Money is grouped the Bangladeshi way — 12,34,567 rather than 1,234,567.
