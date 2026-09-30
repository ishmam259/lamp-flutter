import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamp_flutter/core/invoice/invoice_artifacts.dart';
import 'package:lamp_flutter/core/models/domain_models.dart';
import 'package:lamp_flutter/core/world/clock.dart';

/// The invoice PDF has to be reproducible. The ledger takes its hash when the
/// invoice is minted, the manufacturer and the bank each render it again
/// later, and the bank can only record ("anchor") a file whose hash matches.
/// If two renders differ, no bank can ever finance the invoice; if a `pdf`
/// release changes the output, every invoice minted before it stops passing.
Invoice _invoice({String id = 'INV-00999', String token = 'RCV-00999'}) => Invoice(
      invoiceId: id,
      tokenId: token,
      manufacturerId: 'mfr-shomota',
      pharmacyDid: 'did:lamp:pharmacy:test',
      lineItems: [
        LineItem(
          sku: 'SHM-PARA-500',
          name: 'Paracetamol',
          strength: '500 mg',
          quantity: 10000,
          cartons: 2,
          unitPrice: 1.2,
          lineValue: 12000.0,
        ),
      ],
      value: 12000.0,
      termsDays: 45,
      issuedAt: DemoClock.demoEpoch,
      dueDate: DemoClock.demoEpoch + 45 * 86400000,
      cartonCount: 2,
    );

void main() {
  test('the same invoice renders to the same bytes', () async {
    final a = await InvoiceArtifacts.renderInvoicePdf(invoice: _invoice());
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final b = await InvoiceArtifacts.renderInvoicePdf(invoice: _invoice());
    expect(b, equals(a));
  });

  test('different invoices render to different bytes', () async {
    final a = await InvoiceArtifacts.issuedHash(_invoice());
    final b = await InvoiceArtifacts.issuedHash(
      _invoice(id: 'INV-01000', token: 'RCV-01000'),
    );
    expect(a, isNot(b));
  });

  test('carries no creation date and a pinned document ID', () async {
    final text = latin1.decode(
      await InvoiceArtifacts.renderInvoicePdf(invoice: _invoice()),
    );
    expect(text, isNot(contains('/CreationDate')));
    expect(text, contains('/ID[<'));
  });

  test('the bytes have not moved (pdf package pinned in pubspec.yaml)',
      () async {
    // If this fails after a dependency change, the new pdf release renders
    // differently: every invoice already minted would stop passing the
    // bank's check. Don't update the hash; keep the old version.
    expect(
      await InvoiceArtifacts.issuedHash(_invoice()),
      equals('0d3010e1b502985c290599f469dfdf85d12cbdc73233c43282e8f311cd046d3e'),
    );
  });
}
