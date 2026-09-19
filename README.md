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

Token ids (`RCV-00235`) and both rate curves match the TypeScript seed, so
Meghna wins the deterministic match at **80% advance / 8.8% fee** on a BUILDING
counterparty with the same band values on both sides. The seeded world now also
carries the TypeScript's seven pharmacies and its five in-flight consignments.

These remain open, and are documented rather than fixed:

- **No invoice document anchoring.** `anchorInvoiceDocument` and the PDF it
  commits to have no counterpart here, so the rule that no bank may advance
  against an invoice it has not checked itself does not exist on this side. It
  is the one eligibility check that is the financier's own job.
- **Line items are disclosed to both banks at mint.** `contract.dart` writes the
  private collection to `ManufacturerMSP`, `MeghnaMSP` and `PadmaMSP`; the
  TypeScript writes it to the submitter alone.
- **The competitive match is simulated.** `_LedgerCtx.getPrivate` gates on
  collection membership, so `matchAndAdvance` sees only the submitting bank's
  curve. The TypeScript leaves it ungated inside chaincode on purpose so the
  contract can compare both. Here the Meghna/Padma seat switcher stands in.
- **GS1.** The payload is the human-readable `(01)…(17)…(10)…(21)…` form rather
  than the FNC1 element string, the expiry is passed pre-formatted rather than
  converted, and the GTIN check digit is computed with the weights shifted one
  position. Each hashes consistently within this application, but no carton hash
  agrees with the TypeScript's, and a physically printed GS1 DataMatrix would be
  refused. Worth closing before anything is printed on a real carton.
- **The block hash does not cover the write set.** `canonicalJson` has no branch
  for arbitrary objects, so every `WriteEntry` serialises as its `toString`.

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

## The world, and what reads it

The seeded world carries seven pharmacies with their own credit histories, five
consignments in flight at demo start — some minted-but-undelivered, some
delivered-but-unfinanced — and the hero invoice `INV-00235`. That is what makes
the lists on each screen worth filtering: the MPO's route has several stops, the
bank's queue has an eligible section and an awaiting-window section, and a
receivable visibly moves between them.

Screens do not reach into the world themselves. `core/world/queries.dart` joins
each token on the ledger with its invoice, its pharmacy and its delivery, and
answers the questions the chaincode is about to be asked — is this owed, is it
payable, may it be financed yet, has every carton been recorded. A screen that
asks those questions cannot offer an action the ledger will refuse, which is the
class of defect that `Bug report/Report 01.md` collected.

## Status

`flutter analyze` is clean and `flutter test` passes 133:

- **`chaincode_test.dart`** (24) — policy parsing, world seeding, carton-hash
  rejection, the Building→Established upgrade on the eighth settled cycle, the
  settle/dispute/finance state guards, and persistence round trips.
- **`world_test.dart`** (20) — the seeded world's shape, and the predicates the
  screens filter on: what is open, what is payable, what is financeable, what
  the 90% confirmation threshold means, and that a signed-for stop leaves the
  route.
- **`flows_test.dart`** (11) — the five defects in `Bug report/Report 01.md`,
  asserted on screen at 360x800 rather than in the model.
- **`layout_test.dart`** (78) — every screen and tab at three device sizes in
  both themes, guarding against overflow.

## Notes

- Company names are fictional. Real manufacturer or bank branding in a live
  financing interface would imply participation that does not exist.
- Money is grouped the Bangladeshi way — 12,34,567 rather than 1,234,567.
