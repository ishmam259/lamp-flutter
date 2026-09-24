# Make `lamp-flutter` pass the BCOLBD / IBCOL DEV prototype rubric

## Context

The Flutter app is now the sole competition PoC. No Fabric — everything stays inside the app.

The concrete spec is already in the repo: `LaMP/BLOCKCHAIN OLYMPIAD BANGLADESH Blockchain Guideline.pdf`
(BCOLBD 2026, §2 Prototype Evaluation). IBCOL DEV mirrors it. It opens with a **mandatory gate**:

> **MUST HAVE BOTH TO PROCEED** — i. a user interface · ii. **the prototype must write to a blockchain**

Then 100 graded points: Problem & Solution 40 · **Privacy & Security 20** · **Architecture 20** ·
Governance 20. Those middle two ask, verbatim: *"how does it address key management?"*, *"will data
unintentionally have leaked to unauthorized parties?"*, *"does the system have controls for who can
access specific parts?"*, *"How are transactions verified? … what is the setup of the consensus? …
who are the orderers, peers etc.?"*, *"Is there a digital identity system in place?"*

**We fail the mandatory gate today, and the TypeScript reference says so in writing.**
`LaMP/lib/chain/ledger.ts:96-103` states its local driver *"is NOT a blockchain, and it does not
satisfy the BCOLBD mandatory back-end criterion"*, sets `describe().authoritative = false`, and
surfaces that in its UI. **The Dart port kept the simulation and dropped the disclosure.**
`ChainDescriptor` sits in `ledger_models.dart:193` with `peerCount: 4`, `tlsEnabled: true`
hard-coded — never constructed, never rendered.

Two audits of the app found the substance is absent everywhere the UI claims it:

| What the UI / docs claim | What the code does |
|---|---|
| A hash chain | The block payload hashes `canonicalJson(tx.writes)`, which falls through to `jsonEncode(value.toString())` at [crypto.dart:37](lib/core/chain/crypto.dart:37) because `WriteEntry` has no `toString`. **Every write hashes as the literal `"Instance of 'WriteEntry'"`** — the hash commits to the *number* of writes and nothing else. Under dart2js minification it hashes differently again. Nothing ever recomputes a hash. |
| "SIGNATURES & MSP ENDORSEMENTS", `cert: <fp>` | No asymmetric crypto anywhere in `lib/`. `signature` = `SHA256("sig:<msp>:<txId>")[0:24]`, `certFingerprint` = `SHA256("cert:<msp>")[0:16]` — a per-MSP constant ([ledger.dart:195](lib/core/chain/ledger.dart:195)). |
| Endorsement policy | `endorsers` is never passed by any caller, so the signer set is always all three endorsing MSPs. **The policy is structurally incapable of failing.** `satisfies` also returns `true` on an empty policy string ([policy.dart:123](lib/core/chain/policy.dart:123)). The regulator screen renders a permanently-green "Quorum held". |
| Access control | `asMsp` is an unauthenticated caller assertion; the bank seat is a `PopupMenuButton`. Every `LaMPState` action hard-codes `Msp.manufacturerMSP` — the pharmacy settles *as the manufacturer*. `Msp.fromId` resolves any unknown id to `ManufacturerMSP`. |
| Private data collections | `PrivateEntry.toJson()` persists **cleartext** into the same SharedPreferences key — Meghna's rate curve is readable from `localStorage`. Private write hashes never enter a block hash. The "sealed" UI branch is unreachable (`isVisible: true` hard-coded). |
| Pharmacy signature | Every token carries the same constant `"sig:" + SHA256("mock-signature-stroke")[0:16]`. The pad's strokes never leave the widget; `onPanStart` alone opens the gate, so **one dot signs for 25 cartons**. |
| Tamper evidence | No hash recomputed, no MAC on the store. Editing `localStorage` to set a token `SETTLED` or a tier `PRIME` is accepted verbatim. `TxStatus.fromId` defaults unknown input to **`VALID`**. |
| "The ledger is the system of record" | `setWorldDirect` writes six of the seven credit histories with **no transaction, no block, no endorsement** ([seed.dart:587](lib/core/world/seed.dart:587)) — and those histories price every advance. |
| Anchored invoice PDF | `pdf 3.12.0` embeds `DateTime.now()` in `/CreationDate` and the document ID. **The PDF is not byte-deterministic**, so the doc-comment premise at [invoice_artifacts.dart:215](lib/core/invoice/invoice_artifacts.dart:215) is false and re-rendering permanently locks the token out of financing. And when nothing is yet anchored, **any** picked file shows "Hash matches" ([verify_anchor_sheet.dart:119](lib/features/bank/verify_anchor_sheet.dart:119)). |
| GS1 / DGDA traceability | The GTIN check digit weights the wrong 13 positions — `makeGtin('890123400101')` → `…1013`, correct is `…1011`. All ten seeded GTINs are invalid. The payload is the human-readable `(01)…` form, not the FNC1 element string. `DataMatrixView` draws LCG noise seeded from `String.hashCode`. |

**Intended outcome:** the app genuinely satisfies the mandatory back-end gate, and every claim on
screen is one the code can defend under questioning.

---

## The decision this plan rests on

Without Fabric, "writes to a blockchain" has to be earned in-app. A single-process append-only log
is a *ledger*, not a blockchain, and a judge will say so. **Phase 2 therefore makes the app
multi-peer over the LAN**: each running instance is a peer holding its own MSP key; a transaction is
broadcast, independently simulated and signed by peers, and commits only when the policy is
satisfied by **verified** signatures from distinct devices. Three phones on one Wi-Fi is a real
permissioned network, and *"who are the peers?"* has an answer you can point at.

Phase 1 is required either way. If Phase 2 runs out of time, Phase 1 plus restoring the honest
`authoritative: false` disclosure is the fallback — but it concedes the mandatory gate.

---

## Phase 0 — Unbreak the build (blocks everything)

Nothing below can be verified until this is done.

- **`flutter test` cannot run at all.** `path_provider` → `path_provider_foundation` → `objective_c`,
  whose native-assets hook fails on the space in `D:\VSCODE\Blockchain Olympiad`. Drop
  `path_provider` (use `share_plus`'s `XFile.fromData`, which needs no temp file) or move the
  checkout to a space-free path. Dropping it also removes the JNI/NDK/CMake requirement it dragged in.
- **The web build does not compile** — unguarded `dart:io` at `verify_anchor_sheet.dart:17` and
  `manufacturer_screen.dart:5`. Conditional import or `kIsWeb` guard. The CI `web` job
  (`.github/workflows/ci.yml:78`) is failing today.
- **Three tests are invalidated** by the new `documentHash` guard in `matchAndAdvance`
  (`world_test.dart:168`, `flows_test.dart:152`, `flows_test.dart:186`) — anchor in the seed.
- `pubspec.yaml:22` declares `sdk: ^3.9.2` but the lockfile needs `>=3.11.0`. Pin both, and pin the
  Flutter channel in CI (it currently floats on `stable` while local is a 3.47 pre-release).
- Remove committed machine state: `android/local.properties`, `hs_err_pid*.log`, `replay_pid*.log`,
  `android/.gradle/`, `.kotlin/errors/`.

## Phase 1 — Make the cryptography real

All inside `lib/core/chain/`. This is the precondition for Phase 2 having anything to verify.

**1.1 Stop the silent hash failure.** `canonicalJson` must **throw** on any unhandled type instead of
`jsonEncode(value.toString())`. One line, and it converts this whole class of defect from silent to
loud. Also make numbers JS-compatible (integral doubles emit `182400`, not `182400.0` — otherwise
`lineItemsHash` can never match the TypeScript) and stop stringifying map keys for lookup
([crypto.dart:30-33](lib/core/chain/crypto.dart:30)), which today makes the encoder
non-injective — the one property a canonical encoder must have.

**1.2 Make the block hash commit to the block.** Give `WriteEntry` a `hash` and a `toJson`, mirroring
`LaMP/lib/chain/ledger.ts:170`. The payload must cover `prevHash`, height, txId, timestamp, status,
fn, **submitter**, **args digest**, **policy string**, `writes.map((key, hash))`,
`privateWrites.map((collection, key, hash))`, and the events — none of the bold items are covered today.

**1.3 Real keys and real signatures.** Add `package:cryptography` (Ed25519). A keypair per MSP plus
one per device, generated on first run, held in `flutter_secure_storage` (Keystore / Keychain) — the
literal answer to *"how does it address key management?"*. Sign the canonical proposal; `Endorsement`
gains an `ok` field and a real signature over the proposal digest.

**1.4 Evaluate the policy against verified signers.** `PolicyParser.satisfies` must receive the MSPs
whose signatures **verified**, not `Msp.values.where(isEndorsing)`. Delete the unused `endorsers`
parameter and the empty-policy fail-open at `policy.dart:123`. Move evaluation to *after* simulation,
as Fabric and the TypeScript both do. Honour `LeafNode.role`, which is parsed and discarded. The
parser itself is the strongest code in the layer — it has simply never been handed a set that could fail.

**1.5 Identity per persona.** Each persona gets a device credential; `asMsp` stops being an assertion
and becomes what the signature proves. The bank seat switcher then switches *keys*. This answers
*"is there a digital identity system?"* and *"controls for who can access specific parts?"* in one
change, and the existing `did:lamp:…` identifiers become the subject of those credentials rather
than decoration.

**1.6 `verifyChain()`.** Recompute every block hash and replay world state from the write sets;
compare against the restored `_world`, and refuse a world that fails. Add an HMAC over the store
payload, and make every `fromId` throw instead of failing open to `VALID` / `ManufacturerMSP` /
`BUILDING`. Validate `DemoClock.restore`'s offset for sign. Surface the result in the regulator
screen — this turns the tamper gap into a demoable feature and is the cleanest answer to *"how are
transactions verified?"*.

**1.7 Close the privacy leak.** `PrivateEntry.toJson()` must not persist cleartext
([ledger.dart:20](lib/core/chain/ledger.dart:20)) — encrypt under the member key or keep
only the digest. Revert `putPrivate` at mint to the submitter alone
([contract.dart:85](lib/core/chain/contract.dart:85)) instead of all three MSPs. Wire
the unreachable sealed branch of `PrivateSeal` to a real membership check so switching seats visibly
seals the line items. Set `android:allowBackup="false"` — Auto Backup currently uploads the whole
world, including base64 invoice PDFs, to the user's Google account. **20 points ride on this section.**

**1.8 Real signature capture.** `SignaturePad` must export its strokes; hash *those* into
`pharmacySignature`, gate on ink area rather than `onPanStart`, and require a pharmacy principal on
`confirmReceipt` instead of `AND('ManufacturerMSP.peer')`.

**1.9 Delete `setWorldDirect`.** Seed the six credit histories through `settle` like Rahman's, so no
state exists that the ledger did not produce.

## Phase 2 — Make it a network

**2.1 `ChainGateway` abstraction.** Port the interface from `LaMP/lib/chain/types.ts` so `LaMPState`
depends on an interface, not a concrete `LocalLedger` ([lamp_state.dart:45](lib/core/state/lamp_state.dart:45)).
Two implementations: the embedded ledger (single-device / offline) and the peer client below.

**2.2 Discovery and transport.** `multicast_dns` to find peers on the LAN, WebSocket for transport.
Each instance advertises its MSP and public key. **Add `INTERNET` to the release manifest** — it is
currently debug/profile-only, which is why the release APK cannot open a socket.

**2.3 Distributed endorsement.** The submitting peer broadcasts a proposal; each receiving peer
simulates it independently against its own world state and returns a signed endorsement or a refusal.
The transaction commits only when `satisfies` passes over the **verified** signer set. Endorsement
failure becomes reachable — and demonstrable on stage by killing a peer.

**2.4 Ordering and finality.** Simplest defensible choice: a designated ordering peer (the
manufacturer node) sequences committed blocks and gossips them; peers accept a block only if its
hash chain and every endorsement verify. Document the trade-off honestly — crash-fault tolerant, not
Byzantine — because *"risk anticipation and trade-offs"* rewards saying so.

**2.5 Offline sign-and-forward.** Sign proposals on-device while offline, submit on reconnect. Note
that **the offline queue is currently dead code** — nothing ever appends to `_offlineQueue`, so
`drainScanQueue` and `recordPoDBatch` are unreachable from the running app, and the OFFLINE switch
only changes an icon. This phase is what makes that feature real.

## Phase 3 — Remove what is fake, fix what is wrong

**3.1 The anchor feature rests on a false premise.** Either make the PDF deterministic (pass a fixed
`creationDate`/`documentID` derived from `token.issuedAt`) or stop hashing a re-rendered artifact and
hash the stored bytes only. Then fix the fabricated verdict: with nothing anchored, any picked file
currently reports "Hash matches" and enables the anchor button. Add a `%PDF-` magic check, a size cap
(`withData: true` loads an unbounded file into memory), and filename sanitisation before it is
concatenated into a path.

**3.2 GS1.** Fix `makeGtin` to weight over the full 13 digits
([gs1.dart:19](lib/core/world/gs1.dart:19)); regenerate the ten seeded GTINs and the
stray. Emit the real FNC1 element string as the payload, keep `humanGs1()` for display, add the
missing `yymmdd()` converter and the `decodeGs1` century rule. Replace `DataMatrixView` with the real
`QrPainter` the app already uses in `invoice_artifacts.dart`. Stop `gs1.dart:53` swallowing parse
failures silently.

**3.3 Chaincode validation gaps.** `settle` **never validates `amount`** — settle for `0` and still
earn a credit cycle and a tier upgrade. `mintReceivable` doesn't check `token:$tokenId` for
existence, so a reused tokenId silently overwrites a live token; `cartonHashes` is neither
deduplicated nor bounded. `recordPoD`'s `substring(0,10)` throws `RangeError` instead of
`ChaincodeException`. `confirmReceipt` has no idempotency or dispute guard. The `DISPUTED` branch in
`matchAndAdvance` is unreachable.

**3.4 Stop reporting success the ledger refused.** `res.ok` is never read on the MPO returns flow
(`mpo_screen.dart:1158`) or the pharmacy dispute (`pharmacy_screen.dart:822`) — both say "Dispute
raised" on a refusal. `_drainQueue` clears the queue regardless of `res.ok`, silently discarding
every queued scan.

**3.5 Dead features — wire or delete.** `_scanBannerError` is never set, so the misroute rejection
banner never appears. `markCartonRejected` has no callers. The demo director's "Jump to a seat" is a
no-op because nothing reads `_currentPersona`. The on-screen cascade the README documents does not
exist, and the "Open camera scanner" button is still live on desktop where the plugin has no
implementation. `LocalLedger.events` has no subscribers and is never closed.

**3.6 Ship-quality Android.** The release APK is **debug-signed** with both template TODOs intact
(`android/app/build.gradle.kts:34-37`). Add a real signing config, pin `minSdk`/`targetSdk`, enable
minification. Add `sharePositionOrigin` to all three `Share.shareXFiles` calls — without it
`UIActivityViewController` **hard-crashes on iPad**, which `Info.plist` advertises support for.

**3.7 Bound the UI.** The mint stepper has no cap — holding `+` mints a 10,000-carton invoice and
hashes it synchronously on the UI isolate. The mint button is always enabled and has no re-entrancy
guard, so a double-tap fires two mints that race on `_nextInvoiceNumber()`. Force-unwraps of
`view.invoice!` / `view.delivery!` red-screen on a partial restore, on a field the model declares
nullable for exactly that reason.

**3.8 Lifecycle rail order.** It reads `… Financed → Document anchored → Settled`, but anchoring
*precedes* financing, so the `: 2` branch is dead and the anchor step never lights up when it happens.

## Phase 4 — Scale, adversarial tests, and the write-up

**4.1 Scale.** `tokenViews` is invalidated on every mutation and rebuilt as **O(tokens × invoices)**
with a `fromJson` per token per frame — index the joins instead. `_snapshot()` serialises **every
transaction twice** (inside `blocks[].txs` and again in the flat `txs` array), each carrying the full
token JSON in its write set. At ~50 tokens the snapshot passes the **5 MB `localStorage` ceiling**,
`save()` returns `false`, and the only report is a `debugPrint` that is a **no-op in release** —
silent total data loss. Bound or checkpoint the ledger; every refused scan currently costs a
permanent block, and the scanner re-arms refusals every 400 ms.

**4.2 Adversarial tests.** The rubric names *"edge-case handling, stress testing, and cybersecurity
considerations"* — so test the attacks: tampered store rejected, forged signature rejected, policy
failure on a missing endorser, replayed txId rejected, malformed GS1 rejected, non-PDF bytes
rejected, `settle` with a wrong amount rejected, a 500-token world for scale. These are the tests
worth showing a judge. Current coverage has **no integration tests, no golden tests, no stress or
property tests**, zero tests on `verify_anchor_sheet.dart`, `invoice_artifacts.dart`,
`carton_scanner_sheet.dart`, `confirmReceipt`, or any `LaMPState` snapshot round-trip.

**4.3 The written deliverables.** `docs/` contains screenshots and no prose, while `contract.dart`
cites *"whitepaper §4.2"*, *"§4.4"*, *"§4.6"* — **every one of those references is dangling.** Write,
in `docs/`: the architecture spec (consensus setup, peer roles, MSPs, channel, on-chain vs off-chain
split, key management, identity, access control), the token state machine as a transition table, the
endorsement-policy rationale, a threat model, and a known-limitations document (the README's "Known
divergences" is the seed of a good one). Then correct the docs that are now false: the README
advertises a web build that does not compile, an on-screen cascade that does not exist, document
anchoring as *absent* when it is the newest feature, and test counts that are wrong in every figure.

---

## Verification

1. `flutter analyze` clean and `flutter test` **actually runs** — Phase 0 gates everything else.
2. Adversarial suite green, each test named for the attack it defeats.
3. **Tamper demo:** hand-edit `localStorage` to mark a token `SETTLED`, relaunch, watch the app refuse
   the world and name the failing block.
4. **Endorsement demo:** three instances on one Wi-Fi; kill one, watch a transaction requiring its
   signature be refused; restart it, watch the same transaction commit.
5. **Privacy demo:** switch from Meghna to Padma and watch the rate-curve line items seal to a hash.
6. Walk the five original `Bug report/Report 01.md` flows for regressions.
7. `flutter build apk --release` with the absolute-`JAVA_HOME` command in `CLAUDE.md`, and confirm
   the artifact is **not** debug-signed.

## Sequencing

Phase 0 first — it is a hard blocker. Then 1.1, 1.2 and 3.2 are roughly an hour between them and
remove the three findings a judge reaches first. Phase 1 is worth completing regardless of how far
Phase 2 gets. **Phase 2 is the largest single piece of work here** and should be scoped against the
time actually left before submission; if it is cut, restore the `authoritative: false` disclosure
rather than leaving the claim standing.
