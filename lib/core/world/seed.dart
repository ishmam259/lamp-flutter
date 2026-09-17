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

  static Future<Map<String, dynamic>> buildWorld(LocalLedger ledger, DemoClock clock) async {
    ledger.clear();
    clock.reset();

    final now = clock.now;

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

    // Write credit history directly into world state
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
        'lineItems': [
          LineItem(
            sku: products[0].sku,
            name: products[0].name,
            strength: products[0].strength,
            quantity: 5000,
            cartons: 1,
            unitPrice: products[0].unitPrice,
            lineValue: 6000.0,
          ).toJson()
        ],
      },
      asMsp: Msp.manufacturerMSP,
      nowTimestamp: now - 350 * day,
    );

    // Write the credit history with the full 7-cycle history directly
    ledger.setWorldDirect('credit:$rahmanDid', creditHistory.toJson());
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

    // 3. Create the Main Demo Consignment: INV-00235
    // 25 cartons for Rahman Medical Hall
    final demoInvoiceId = 'INV-00235';
    final demoTokenId = 'RCV-00235';
    final demoCartonCount = 25;

    final demoLineItems = [
      LineItem(
        sku: 'SHM-PARA-500',
        name: 'Paracetamol',
        strength: '500 mg',
        quantity: 50000,
        cartons: 10,
        unitPrice: 1.2,
        lineValue: 60000.0,
      ),
      LineItem(
        sku: 'SHM-ESOM-20',
        name: 'Esomeprazole',
        strength: '20 mg',
        quantity: 9600,
        cartons: 8,
        unitPrice: 7.5,
        lineValue: 72000.0,
      ),
      LineItem(
        sku: 'SHM-METF-500',
        name: 'Metformin HCl',
        strength: '500 mg',
        quantity: 21000,
        cartons: 7,
        unitPrice: 2.4,
        lineValue: 50400.0,
      ),
    ];

    final demoDeclaredValue = demoLineItems.fold<double>(0.0, (s, l) => s + l.lineValue);

    // Build the 25 cartons + plant Carton #14 from another invoice
    final demoCartons = <Carton>[];
    final demoCartonHashes = <String>[];

    for (int i = 1; i <= demoCartonCount; i++) {
      final cid = 'CTN-$i';
      final sku = i <= 10 ? 'SHM-PARA-500' : (i <= 18 ? 'SHM-ESOM-20' : 'SHM-METF-500');
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
}
