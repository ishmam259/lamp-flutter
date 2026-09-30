import 'dart:math';

import '../invoice/invoice_artifacts.dart';
import '../chain/crypto.dart';
import '../chain/ledger.dart';
import '../models/domain_models.dart';
import 'clock.dart';
import 'gs1.dart';

class SeedData {
  static const int day = 86400 * 1000;

  static final Manufacturer manufacturer = Manufacturer(
    id: 'mfr-shomota',
    msp: Msp.manufacturerMSP,
    name: 'Shomota Pharmaceuticals Ltd',
    category: 'TIER2',
    depot: 'Bogura Regional Depot',
  );

  static final List<Product> products = [
    Product(
      sku: 'SHM-PARA-500',
      gtin: GS1Barcode.makeGtin('890123400101'),
      name: 'Paracetamol',
      strength: '500 mg',
      form: 'Tablet',
      unitPrice: 1.2,
      unitsPerCarton: 5000,
    ),
    Product(
      sku: 'SHM-ESOM-20',
      gtin: GS1Barcode.makeGtin('890123400118'),
      name: 'Esomeprazole',
      strength: '20 mg',
      form: 'Capsule',
      unitPrice: 7.5,
      unitsPerCarton: 1200,
    ),
    Product(
      sku: 'SHM-METF-500',
      gtin: GS1Barcode.makeGtin('890123400125'),
      name: 'Metformin HCl',
      strength: '500 mg',
      form: 'Tablet',
      unitPrice: 2.4,
      unitsPerCarton: 3000,
    ),
    Product(
      sku: 'SHM-AMOX-500',
      gtin: GS1Barcode.makeGtin('890123400132'),
      name: 'Amoxicillin',
      strength: '500 mg',
      form: 'Capsule',
      unitPrice: 6.0,
      unitsPerCarton: 1500,
    ),
    Product(
      sku: 'SHM-CETI-10',
      gtin: GS1Barcode.makeGtin('890123400149'),
      name: 'Cetirizine',
      strength: '10 mg',
      form: 'Tablet',
      unitPrice: 1.8,
      unitsPerCarton: 4000,
    ),
    Product(
      sku: 'SHM-SALB-INH',
      gtin: GS1Barcode.makeGtin('890123400156'),
      name: 'Salbutamol',
      strength: '100 mcg',
      form: 'Inhaler',
      unitPrice: 195.0,
      unitsPerCarton: 60,
    ),
    Product(
      sku: 'SHM-ORS-SAC',
      gtin: GS1Barcode.makeGtin('890123400163'),
      name: 'Oral Rehydration Salts',
      strength: '20.5 g',
      form: 'Sachet',
      unitPrice: 6.5,
      unitsPerCarton: 2000,
    ),
    Product(
      sku: 'SHM-CEFT-1G',
      gtin: GS1Barcode.makeGtin('890123400170'),
      name: 'Ceftriaxone',
      strength: '1 g',
      form: 'Injection',
      unitPrice: 145.0,
      unitsPerCarton: 200,
    ),
    Product(
      sku: 'SHM-LOSA-50',
      gtin: GS1Barcode.makeGtin('890123400187'),
      name: 'Losartan Potassium',
      strength: '50 mg',
      form: 'Tablet',
      unitPrice: 4.2,
      unitsPerCarton: 2400,
    ),
    Product(
      sku: 'SHM-OMEP-20',
      gtin: GS1Barcode.makeGtin('890123400194'),
      name: 'Omeprazole',
      strength: '20 mg',
      form: 'Capsule',
      unitPrice: 3.6,
      unitsPerCarton: 2500,
    ),
  ];

  static final List<Pharmacy> pharmacies = [
    Pharmacy(
      did: 'did:lamp:pharmacy:rahman-medical',
      name: 'Rahman Medical Hall',
      ownerName: 'Abdur Rahman',
      nameBn: 'রহমান মেডিকেল হল',
      phone: '+8801711204488',
      territory: 'Bogura Sadar',
      address: 'Sherpur Road, Bogura Sadar, Bogura',
      licenceNo: 'DGDA-RB-0442197',
      since: DemoClock.demoEpoch - 640 * day,
    ),
    Pharmacy(
      did: 'did:lamp:pharmacy:noor-medico',
      name: 'Noor Medico',
      ownerName: 'Shirin Akter',
      nameBn: 'নূর মেডিকো',
      phone: '+8801812337790',
      territory: 'Rangpur',
      address: 'Station Road, Rangpur Sadar',
      licenceNo: 'DGDA-RP-0338710',
      since: DemoClock.demoEpoch - 410 * day,
    ),
    Pharmacy(
      did: 'did:lamp:pharmacy:bismillah',
      name: 'Bismillah Pharmacy',
      ownerName: 'Kazi Nurul Islam',
      nameBn: 'বিসমিল্লাহ ফার্মেসি',
      phone: '+8801913558021',
      territory: 'Cumilla',
      address: 'Kandirpar, Cumilla',
      licenceNo: 'DGDA-CM-0219654',
      since: DemoClock.demoEpoch - 880 * day,
    ),
    Pharmacy(
      did: 'did:lamp:pharmacy:shafa-drug',
      name: 'Shafa Drug House',
      ownerName: 'Md. Kamruzzaman',
      nameBn: 'শেফা ড্রাগ হাউস',
      phone: '+8801677812345',
      territory: 'Jashore',
      address: 'M.K. Road, Jashore',
      licenceNo: 'DGDA-JS-0501338',
      since: DemoClock.demoEpoch - 220 * day,
    ),
    Pharmacy(
      did: 'did:lamp:pharmacy:alif-medicine',
      name: 'Alif Medicine Corner',
      ownerName: 'Rokeya Begum',
      nameBn: 'আলিফ মেডিসিন কর্নার',
      phone: '+8801534229087',
      territory: 'Bogura Sadar',
      address: 'Thanthania, Bogura',
      licenceNo: 'DGDA-RB-0447012',
      since: DemoClock.demoEpoch - 150 * day,
    ),
    Pharmacy(
      did: 'did:lamp:pharmacy:janata-pharma',
      name: 'Janata Pharma',
      ownerName: 'Sohel Mahmud',
      nameBn: 'জনতা ফার্মা',
      phone: '+8801755690012',
      territory: 'Rangpur',
      address: 'Jahaj Company More, Rangpur',
      licenceNo: 'DGDA-RP-0341882',
      since: DemoClock.demoEpoch - 1100 * day,
    ),
    Pharmacy(
      did: 'did:lamp:pharmacy:hilful-fujul',
      name: 'Hilful Fujul Medical Store',
      ownerName: 'Anwar Hossain',
      nameBn: 'হিলফুল ফুজুল মেডিকেল স্টোর',
      phone: '+8801399471250',
      territory: 'Cumilla',
      address: 'Chawkbazar, Cumilla',
      licenceNo: 'DGDA-CM-0224419',
      since: DemoClock.demoEpoch - 300 * day,
    ),
  ];

  static final List<Mpo> mpos = [
    Mpo(
      id: 'mpo-kamrul',
      name: 'Kamrul Hasan',
      phone: '+8801719443021',
      territory: 'Bogura Sadar',
      deviceId: 'LMP-DEV-4471',
      manufacturerId: 'mfr-shomota',
    ),
    Mpo(
      id: 'mpo-riaz',
      name: 'Riazul Karim',
      phone: '+8801811229546',
      territory: 'Rangpur',
      deviceId: 'LMP-DEV-4472',
      manufacturerId: 'mfr-shomota',
    ),
  ];

  /// Meghna prices more aggressively at every tier, so it wins the
  /// deterministic match. Padma exists to lose it — and to prove it never saw
  /// Meghna's curve. Values mirror MEGHNA_BANDS / PADMA_BANDS in the
  /// TypeScript seed, which is authoritative.
  static final RateCurve meghnaCurve = RateCurve(
    curveId: 'CURVE-MEGHNA-2026Q3',
    bankMsp: Msp.meghnaMSP,
    registeredAt: DemoClock.demoEpoch - 200 * day,
    bands: [
      const RateCurveBand(
        tier: RecourseTier.newTier,
        advanceRatePct: 70.0,
        feePct: 9.5,
        manufacturerRecoursePct: 100.0,
        maxInvoiceValue: 500000.0,
      ),
      const RateCurveBand(
        tier: RecourseTier.building,
        advanceRatePct: 80.0,
        feePct: 8.8,
        manufacturerRecoursePct: 60.0,
        maxInvoiceValue: 800000.0,
      ),
      const RateCurveBand(
        tier: RecourseTier.established,
        advanceRatePct: 85.0,
        feePct: 8.0,
        manufacturerRecoursePct: 25.0,
        maxInvoiceValue: 1500000.0,
      ),
      const RateCurveBand(
        tier: RecourseTier.prime,
        advanceRatePct: 90.0,
        feePct: 7.2,
        manufacturerRecoursePct: 0.0,
        maxInvoiceValue: 3000000.0,
      ),
    ],
  );

  static final RateCurve padmaCurve = RateCurve(
    curveId: 'CURVE-PADMA-2026Q3',
    bankMsp: Msp.padmaMSP,
    registeredAt: DemoClock.demoEpoch - 186 * day,
    bands: [
      const RateCurveBand(
        tier: RecourseTier.newTier,
        advanceRatePct: 65.0,
        feePct: 9.0,
        manufacturerRecoursePct: 100.0,
        maxInvoiceValue: 400000.0,
      ),
      const RateCurveBand(
        tier: RecourseTier.building,
        advanceRatePct: 75.0,
        feePct: 8.5,
        manufacturerRecoursePct: 70.0,
        maxInvoiceValue: 600000.0,
      ),
      const RateCurveBand(
        tier: RecourseTier.established,
        advanceRatePct: 82.0,
        feePct: 7.6,
        manufacturerRecoursePct: 30.0,
        maxInvoiceValue: 1200000.0,
      ),
      const RateCurveBand(
        tier: RecourseTier.prime,
        advanceRatePct: 88.0,
        feePct: 7.0,
        manufacturerRecoursePct: 0.0,
        maxInvoiceValue: 2500000.0,
      ),
    ],
  );

  /// Fixed so the world is the same on every run.
  ///
  /// The TypeScript seeder uses a mulberry32 keyed on 0x1a3f for the same
  /// reason (`seed.ts:30-52`): a demo that reshuffles itself between takes
  /// cannot be rehearsed against.
  static const int _rngSeed = 0x1a3f;

  /// A settled history for one of the pharmacies that is not the demo
  /// counterparty, with the tier the chaincode would have earned it.
  ///
  /// The tier is derived rather than asserted, so this cannot drift away from
  /// `LaMPContract._earnedTier`: 3 cycles is Building, 8 is Established, and
  /// two or more late settlements cost a tier.
  static CreditHistory _historyFor(String did, int now, Random rng) {
    final cycleCount = 2 + rng.nextInt(8); // 2..9, as `seed.ts:495`
    final cycles = <CreditCycle>[];
    var onTime = 0;
    var late = 0;

    for (int i = 0; i < cycleCount; i++) {
      final termsDays = const [30, 45, 60][rng.nextInt(3)];
      final gap = 50 + rng.nextInt(21);
      // Every settled cycle has to land wholly in the past: the chaincode
      // refuses a settlement dated after the transaction recording it, and a
      // seeded world is not exempt from that rule.
      final issued = now - ((cycleCount - i) * gap + termsDays + 20) * day;
      final due = issued + termsDays * day;
      final isLate = rng.nextDouble() < 0.18;
      final daysLate = isLate ? 3 + rng.nextInt(14) : 0;
      final settled = isLate ? due + daysLate * day : due - (1 + rng.nextInt(4)) * day;

      isLate ? late++ : onTime++;
      cycles.add(CreditCycle(
        tokenId: 'RCV-HIST-${did.hashCode.abs() % 1000}-$i',
        invoiceId: 'INV-HIST-${did.hashCode.abs() % 1000}-$i',
        value: (60000 + rng.nextInt(240000)).toDouble(),
        dueDate: due,
        settledAt: settled,
        observedAt: settled,
        onTime: !isLate,
        daysLate: daysLate,
      ));
    }

    var tier = cycleCount >= 16
        ? RecourseTier.prime
        : cycleCount >= 8
            ? RecourseTier.established
            : cycleCount >= 3
                ? RecourseTier.building
                : RecourseTier.newTier;
    if (late >= 2 && tier != RecourseTier.newTier) {
      tier = RecourseTier.values[tier.index - 1];
    }

    return CreditHistory(
      pharmacyDid: did,
      cycles: cycles,
      tier: tier,
      onTimeCount: onTime,
      lateCount: late,
      defaultCount: 0,
    );
  }

  /// Build one consignment's invoice and its cartons.
  ///
  /// Serials carry the invoice number. The carton hash is taken over the GS1
  /// payload, so two invoices minting an identical payload would let a carton
  /// from one satisfy the other's membership test — which is the very check
  /// the misrouted-carton beat exists to demonstrate (`seed.ts:149-153`).
  static ({Invoice invoice, List<Carton> cartons}) _materialise({
    required String invoiceId,
    required String tokenId,
    required String pharmacyDid,
    required int cartonCount,
    required int termsDays,
    required int issuedAt,
    required Random rng,
  }) {
    final kinds = 2 + rng.nextInt(2); // 2 or 3 SKUs
    final chosen = <Product>[];
    while (chosen.length < kinds) {
      final candidate = products[rng.nextInt(products.length)];
      if (!chosen.contains(candidate)) chosen.add(candidate);
    }

    // Spread the cartons across the chosen SKUs, remainder onto the first.
    final per = cartonCount ~/ kinds;
    final counts = List<int>.generate(
      kinds,
      (i) => i == 0 ? per + (cartonCount - per * kinds) : per,
    );

    final numeric = invoiceId.replaceAll(RegExp(r'\D'), '');
    final lineItems = <LineItem>[];
    final cartons = <Carton>[];
    var serial = 1;

    for (int i = 0; i < kinds; i++) {
      final product = chosen[i];
      final cartonsForSku = counts[i];
      final quantity = cartonsForSku * product.unitsPerCarton;

      lineItems.add(LineItem(
        sku: product.sku,
        name: product.name,
        strength: product.strength,
        quantity: quantity,
        cartons: cartonsForSku,
        unitPrice: product.unitPrice,
        lineValue: (quantity * product.unitPrice).roundToDouble(),
      ));

      for (int c = 0; c < cartonsForSku; c++) {
        final ser = '$numeric${serial.toString().padLeft(4, '0')}';
        final batch = 'BCH-2026-${(1 + rng.nextInt(9)).toString().padLeft(2, '0')}';
        final gs1 = GS1Barcode.encodeGs1(
          gtin: product.gtin,
          expiry: '280824',
          batch: batch,
          serial: ser,
        );
        cartons.add(Carton(
          cartonId: '$invoiceId-${product.sku}-$ser',
          gs1: gs1,
          hash: LaMPCrypto.sha256Hex(gs1),
          sku: product.sku,
          batch: batch,
          expiry: '2028-08-24',
        ));
        serial++;
      }
    }

    final value = lineItems.fold<double>(0.0, (sum, l) => sum + l.lineValue);

    return (
      invoice: Invoice(
        invoiceId: invoiceId,
        tokenId: tokenId,
        manufacturerId: manufacturer.id,
        pharmacyDid: pharmacyDid,
        lineItems: lineItems,
        value: value,
        termsDays: termsDays,
        issuedAt: issuedAt,
        dueDate: issuedAt + termsDays * day,
        cartonCount: cartonCount,
      ),
      cartons: cartons,
    );
  }

  static Future<Map<String, dynamic>> buildWorld(LocalLedger ledger, DemoClock clock) async {
    ledger.clear();
    clock.reset();

    final now = clock.now;
    final rng = Random(_rngSeed);

    // 1. Register Bank Curves
    await ledger.submit(
      fn: 'registerRateCurve',
      args: {'curve': meghnaCurve.toJson()},
      asMsp: Msp.meghnaMSP,
      nowTimestamp: now - 30 * day,
    );

    await ledger.submit(
      fn: 'registerRateCurve',
      args: {'curve': padmaCurve.toJson()},
      asMsp: Msp.padmaMSP,
      nowTimestamp: now - 25 * day,
    );

    // 2. Seed Rahman Medical Hall 7 Settled Cycles (Building tier with 7/16 cycles)
    final rahmanDid = pharmacies[0].did;
    final historicalCycles = <CreditCycle>[];
    final seededInvoices = <Invoice>[];
    final seededDeliveries = <Delivery>[];

    final cycleValues = [120000.0, 185000.0, 95000.0, 240000.0, 310000.0, 150000.0, 280000.0];
    final cycleDaysAgo = [320, 260, 210, 160, 110, 65, 20];

    for (int i = 0; i < 7; i++) {
      final isLate = (i == 2); // 3rd cycle had a 5-day delay
      final invNum = 100 + i;
      final invId = 'INV-00$invNum';
      final tokId = 'RCV-00$invNum';
      final issued = now - cycleDaysAgo[i] * day;
      final due = issued + 45 * day;
      final settled = isLate ? due + 5 * day : due - 2 * day;

      final cycle = CreditCycle(
        tokenId: tokId,
        invoiceId: invId,
        value: cycleValues[i],
        dueDate: due,
        settledAt: settled,
        observedAt: settled,
        onTime: !isLate,
        daysLate: isLate ? 5 : 0,
      );
      historicalCycles.add(cycle);
    }

    final creditHistory = CreditHistory(
      pharmacyDid: rahmanDid,
      cycles: historicalCycles,
      tier: RecourseTier.building,
      onTimeCount: 6,
      lateCount: 1,
      defaultCount: 0,
    );

    // One historical cycle replayed through the chaincode, so the ledger opens
    // with a completed lifecycle on it rather than only with mints.
    //
    // It is carried all the way to SETTLED. Left DELIVERED — as it was — it
    // would now surface in every list that the screens derive: a year-old
    // receivable sitting in the bank's financing queue and on the pharmacy's
    // "what do I owe".
    final histLineItems = [
      LineItem(
        sku: products[0].sku,
        name: products[0].name,
        strength: products[0].strength,
        quantity: 5000,
        cartons: 1,
        unitPrice: products[0].unitPrice,
        lineValue: 100000.0,
      ),
    ];

    await ledger.submit(
      fn: 'mintReceivable',
      args: {
        'tokenId': 'RCV-SEED-HIST',
        'invoiceId': 'INV-SEED-HIST',
        'manufacturerId': manufacturer.id,
        'buyerDid': rahmanDid,
        'declaredValue': 100000.0,
        'termsDays': 45,
        'issuedAt': now - 350 * day,
        'dueDate': now - 305 * day,
        'cartonHashes': ['seed-hash-01'],
        'lineItems': histLineItems.map((l) => l.toJson()).toList(),
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: now - 350 * day,
    );

    await ledger.submit(
      fn: 'recordPoD',
      args: {
        'tokenId': 'RCV-SEED-HIST',
        'cartonHash': 'seed-hash-01',
        'mpoSignature': 'sig:kamrul',
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: now - 349 * day,
    );

    await ledger.submit(
      fn: 'settle',
      args: {
        'tokenId': 'RCV-SEED-HIST',
        'amount': 100000.0,
        'method': 'Bank Transfer',
        'paymentRef': 'BANKTRANSFER-100235',
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: now - 307 * day,
    );

    seededInvoices.add(Invoice(
      invoiceId: 'INV-SEED-HIST',
      tokenId: 'RCV-SEED-HIST',
      manufacturerId: manufacturer.id,
      pharmacyDid: rahmanDid,
      lineItems: histLineItems,
      value: 100000.0,
      termsDays: 45,
      issuedAt: now - 350 * day,
      dueDate: now - 305 * day,
      cartonCount: 1,
    ));

    // The authoritative credit history goes in last.
    //
    // `settle` above appended its own cycle and recomputed the tier; the
    // hand-written seven-cycle history is what the demo is built around, so it
    // overwrites that rather than racing it.
    ledger.setWorldDirect('credit:$rahmanDid', creditHistory.toJson());

    // Everyone else, so the bank's tier bands and the regulator's distribution
    // have something to render. Ported from `seed.ts:493-508`, but written
    // straight to world state the way Rahman's is, rather than replayed.
    for (int i = 1; i < pharmacies.length; i++) {
      ledger.setWorldDirect(
        'credit:${pharmacies[i].did}',
        _historyFor(pharmacies[i].did, now, rng).toJson(),
      );
    }

    // Invoices in flight at demo start.
    //
    // A few minted-but-undelivered and a few delivered-but-unfinanced, so the
    // MPO's route, the bank's opportunity queue and the manufacturer's board
    // each hold more than one row. Without these the screens have nothing to
    // filter, which is what made a completed stop look "stuck" on the route
    // and a financed invoice look like it never left the queue.
    //
    // Ported from `seed.ts:516-595`.
    const inFlight = <({int pharmacyIndex, bool delivered})>[
      (pharmacyIndex: 1, delivered: true),
      (pharmacyIndex: 2, delivered: false),
      (pharmacyIndex: 3, delivered: true),
      (pharmacyIndex: 4, delivered: false),
      (pharmacyIndex: 5, delivered: true),
    ];

    var invoiceNo = 200;
    // The hero consignment is stop 1; these follow it on the route.
    var sequence = 1;

    for (final f in inFlight) {
      invoiceNo += 1;
      final invoiceId = 'INV-${invoiceNo.toString().padLeft(5, '0')}';
      final tokenId = 'RCV-${invoiceNo.toString().padLeft(5, '0')}';
      final pharmacy = pharmacies[f.pharmacyIndex];
      final issuedAt = now - (3 + rng.nextInt(7)) * day;
      final termsDays = rng.nextBool() ? 30 : 45;

      final built = _materialise(
        invoiceId: invoiceId,
        tokenId: tokenId,
        pharmacyDid: pharmacy.did,
        cartonCount: 10 + rng.nextInt(15),
        termsDays: termsDays,
        issuedAt: issuedAt,
        rng: rng,
      );

      await ledger.submit(
        fn: 'mintReceivable',
        args: {
          'tokenId': tokenId,
          'invoiceId': invoiceId,
          'manufacturerId': manufacturer.id,
          'buyerDid': pharmacy.did,
          'declaredValue': built.invoice.value,
          'termsDays': termsDays,
          'issuedAt': issuedAt,
          'dueDate': built.invoice.dueDate,
          'cartonHashes': built.cartons.map((c) => c.hash).toList(),
          'lineItems': built.invoice.lineItems.map((l) => l.toJson()).toList(),
          'documentSha256': await InvoiceArtifacts.issuedHash(built.invoice),
        },
        asMsp: Msp.manufacturerMSP,
        nowTimestamp: issuedAt,
      );

      seededInvoices.add(built.invoice);
      sequence += 1;

      if (f.delivered) {
        final deliveredAt = issuedAt + day;
        await ledger.submit(
          fn: 'recordPoDBatch',
          args: {
            'tokenId': tokenId,
            'cartonHashes': built.cartons.map((c) => c.hash).toList(),
            'mpoSignature': 'sig:${mpos[0].deviceId}',
          },
          asMsp: Msp.manufacturerMSP,
          nowTimestamp: deliveredAt,
        );

        for (final carton in built.cartons) {
          carton.scannedAt = deliveredAt;
        }

        seededDeliveries.add(Delivery(
          id: 'del-$tokenId',
          invoiceId: invoiceId,
          tokenId: tokenId,
          mpoId: mpos[0].id,
          pharmacyDid: pharmacy.did,
          status: DeliveryStatus.completed,
          sequence: sequence,
          cartons: built.cartons,
          startedAt: deliveredAt,
          completedAt: deliveredAt + 38 * 60 * 1000,
          signatureRef: 'offchain://signatures/$tokenId.png',
        ));
      } else {
        seededDeliveries.add(Delivery(
          id: 'del-$tokenId',
          invoiceId: invoiceId,
          tokenId: tokenId,
          mpoId: mpos[0].id,
          pharmacyDid: pharmacy.did,
          status: DeliveryStatus.pending,
          sequence: sequence,
          cartons: built.cartons,
          startedAt: issuedAt,
        ));
      }
    }

    // 3. Create the Main Demo Consignment: INV-00235
    // 5 cartons for Rahman Medical Hall. Kept small on purpose: this is the
    // invoice shown to the judges, and every carton is scanned by hand on
    // camera. Quantities are cartons x the catalogue's units per carton
    // (5,000 / 1,200 / 3,000) and values use the catalogue unit prices.
    final demoInvoiceId = 'INV-00235';
    final demoTokenId = 'RCV-00235';

    final demoLineItems = [
      LineItem(
        sku: 'SHM-PARA-500',
        name: 'Paracetamol',
        strength: '500 mg',
        quantity: 10000,
        cartons: 2,
        unitPrice: 1.2,
        lineValue: 12000.0,
      ),
      LineItem(
        sku: 'SHM-ESOM-20',
        name: 'Esomeprazole',
        strength: '20 mg',
        quantity: 2400,
        cartons: 2,
        unitPrice: 7.5,
        lineValue: 18000.0,
      ),
      LineItem(
        sku: 'SHM-METF-500',
        name: 'Metformin HCl',
        strength: '500 mg',
        quantity: 3000,
        cartons: 1,
        unitPrice: 2.4,
        lineValue: 7200.0,
      ),
    ];

    final demoDeclaredValue = demoLineItems.fold<double>(0.0, (s, l) => s + l.lineValue);
    final demoCartonCount = demoLineItems.fold<int>(0, (s, l) => s + l.cartons);
    // Each carton's SKU follows the line items, so the two cannot disagree.
    final demoCartonSkus = <String>[
      for (final l in demoLineItems) ...List.filled(l.cartons, l.sku),
    ];

    // Build the cartons. The misrouted carton is not one of them: it belongs
    // to another invoice (`foreignCarton`) and is presented separately.
    final demoCartons = <Carton>[];
    final demoCartonHashes = <String>[];

    for (int i = 1; i <= demoCartonCount; i++) {
      final cid = 'CTN-$i';
      final sku = demoCartonSkus[i - 1];
      final gtin = products.firstWhere((p) => p.sku == sku).gtin;
      final gs1 = GS1Barcode.encodeGs1(
        gtin: gtin,
        expiry: '280824',
        batch: 'BCH-2026-08',
        serial: 'SN-${i.toString().padLeft(4, '0')}',
      );
      final chash = LaMPCrypto.sha256Hex(gs1);

      demoCartonHashes.add(chash);
      demoCartons.add(Carton(
        cartonId: cid,
        gs1: gs1,
        hash: chash,
        sku: sku,
        batch: 'BCH-2026-08',
        expiry: '2028-08-24',
      ));
    }

    final demoInvoice = Invoice(
      invoiceId: demoInvoiceId,
      tokenId: demoTokenId,
      manufacturerId: manufacturer.id,
      pharmacyDid: rahmanDid,
      lineItems: demoLineItems,
      value: demoDeclaredValue,
      termsDays: 45,
      issuedAt: now,
      dueDate: now + 45 * day,
      cartonCount: demoCartonCount,
    );

    // Now mint the demo invoice on chain
    await ledger.submit(
      fn: 'mintReceivable',
      args: {
        'tokenId': demoTokenId,
        'invoiceId': demoInvoiceId,
        'manufacturerId': manufacturer.id,
        'buyerDid': rahmanDid,
        'declaredValue': demoDeclaredValue,
        'termsDays': 45,
        'issuedAt': now,
        'dueDate': now + 45 * day,
        'cartonHashes': demoCartonHashes,
        'lineItems': demoLineItems.map((l) => l.toJson()).toList(),
        'documentSha256': await InvoiceArtifacts.issuedHash(demoInvoice),
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: now,
    );

    final demoDelivery = Delivery(
      id: 'del-00235',
      invoiceId: demoInvoiceId,
      tokenId: demoTokenId,
      mpoId: mpos[0].id,
      pharmacyDid: rahmanDid,
      status: DeliveryStatus.pending,
      sequence: 1,
      cartons: demoCartons,
      startedAt: now,
    );

    seededInvoices.add(demoInvoice);
    seededDeliveries.add(demoDelivery);

    return {
      'invoices': seededInvoices,
      'deliveries': seededDeliveries,
      'creditHistory': creditHistory,
      'demoTokenId': demoTokenId,
      'demoInvoiceId': demoInvoiceId,
    };
  }

  /// The GS1 payload used as the "stray carton" for the misroute-rejection
  /// beat. It deliberately belongs to no invoice in the seeded world; when a
  /// scanner reads it the chaincode throws and the UI surfaces the dispute
  /// banner.
  ///
  /// Replaces the duplicated `_misroutedGs1` literal that previously lived on
  /// `mpo_screen.dart`. Both the MPO scan flow and the manufacturer QR-ZIP
  /// download now read from this single source — the carton's hash is also
  /// captured here so the chaincode's `cartonHashes` membership test fails
  /// for the same reason everywhere.
  static const String foreignCartonGs1 =
      '(01)08901234001019(17)280824(10)BCH-FOREIGN(21)SN-9999';
  static const String foreignCartonSku = 'BCH-FOREIGN';
  static const String foreignCartonBatch = 'BX-9999';
  static const String foreignCartonExpiry = '280824';
  static const String foreignCartonId = 'FOREIGN-9999';

  /// The full foreign carton as a `Carton`, with `rejected: true` set so the
  /// UI shows it as already-known-bad without a fresh chaincode round-trip.
  static Carton foreignCarton() {
    return Carton(
      cartonId: foreignCartonId,
      gs1: foreignCartonGs1,
      hash: LaMPCrypto.sha256Hex(foreignCartonGs1),
      sku: foreignCartonSku,
      batch: foreignCartonBatch,
      expiry: foreignCartonExpiry,
      rejected: true,
      rejectReason: 'Does not belong to any invoice on the channel.',
    );
  }
}
