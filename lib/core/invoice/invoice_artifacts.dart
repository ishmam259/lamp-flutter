// Anchored-invoice-document artifacts.
//
// Manufacturer-side generation: render a PDF of the invoice, render PNG QR
// codes for every carton, bundle the whole set into a ZIP whose filename
// mirrors `LaMP/app/api/invoices/[tokenId]/qr-codes/route.ts`. The bank then
// downloads the same PDF (or the manufacturer's), hashes it, and anchors the
// digest to the channel via `anchorInvoiceDocument`.
//
// Pure Dart helpers — no platform-specific I/O. Bytes are returned; the
// caller hands them to `Share.shareXFiles` via `path_provider`.
//
// The renderer uses the `pdf` package for the PDF and `QrPainter` for the
// carton QR PNGs (driven via `PictureRecorder`, the standard headless
// rendering approach in Flutter). The PDF is reproducible (see
// [InvoiceArtifacts.renderInvoicePdf]), so its hash can be fixed on the
// ledger when the invoice is minted.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show Color;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../chain/crypto.dart';
import '../models/domain_models.dart';
import '../world/seed.dart';

class InvoiceArtifacts {
  /// Slugified invoice id used in the ZIP / PDF filename.
  ///
  /// `LaMP/app/api/invoices/[tokenId]/qr-codes/route.ts:91` lowercases the
  /// invoice id for the same purpose; we follow suit.
  static String slugFor(String invoiceId) => invoiceId.toLowerCase();

  /// Filename for the QR-codes ZIP — `inv-00235-cartons-qr.zip`.
  static String zipFilename(String invoiceId) =>
      '${slugFor(invoiceId)}-cartons-qr.zip';

  /// Filename for the anchored invoice PDF — `inv-00235.pdf`.
  static String pdfFilename(String invoiceId) => '${slugFor(invoiceId)}.pdf';

  /* ---------------------------------------------------------------------- */
  /* QR PNG rendering                                                        */
  /* ---------------------------------------------------------------------- */

  /// Render a single GS1 string as a 450x450 PNG buffer.
  ///
  /// Matches the TS `qrcode` options (width 450, margin 2, error correction
  /// 'M', dark `#050807`, light `#ffffff`) so the operator's phone decodes
  /// either side identically. Driven through `PictureRecorder` so we get a
  /// `ui.Image` without a widget tree — works in unit tests and from a
  /// non-Flutter isolate.
  static Future<Uint8List> renderQrPng(String gs1) async {
    final qr = QrPainter(
      data: gs1,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF050807),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF050807),
      ),
      gapless: false,
    );
    final size = ui.Size(450.0, 450.0);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
    );
    // Background fill to match the TS `light: '#ffffff'` option. The painter
    // draws empty modules as transparent; without this fill the PNG would
    // have transparent modules instead of pure white, which `jsQR` and the
    // `mobile_scanner` library both handle, but a uniform white background
    // matches what the operator sees when they save the PNG to the gallery.
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    qr.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode QR PNG for $gs1');
    }
    return byteData.buffer.asUint8List();
  }

  /* ---------------------------------------------------------------------- */
  /* Manifest                                                                */
  /* ---------------------------------------------------------------------- */

  /// Build the JSON manifest that ships inside the QR ZIP.
  ///
  /// Mirrors `LaMP/app/api/invoices/[tokenId]/qr-codes/route.ts:63-83`:
  /// `invoiceId`, `tokenId`, `declaredCartons`, a per-carton array with
  /// `index / cartonId / sku / batch / expiry / hash / gs1`, plus a
  /// `demoStrayCarton` block and an `instructions` string. Pretty-printed
  /// with two-space indent so a human opening the file can read it.
  static Map<String, dynamic> buildManifest({
    required Invoice invoice,
    required List<Carton> cartons,
  }) {
    return {
      'invoiceId': invoice.invoiceId,
      'tokenId': invoice.tokenId,
      'declaredCartons': cartons.length,
      'cartons': [
        for (var i = 0; i < cartons.length; i++)
          {
            'index': i,
            'cartonId': cartons[i].cartonId,
            'sku': cartons[i].sku,
            'batch': cartons[i].batch,
            'expiry': cartons[i].expiry,
            'hash': cartons[i].hash,
            'gs1': cartons[i].gs1,
          },
      ],
      'demoStrayCarton': {
        'gs1': SeedData.foreignCartonGs1,
        'sku': SeedData.foreignCartonSku,
        'batch': SeedData.foreignCartonBatch,
        'expiry': SeedData.foreignCartonExpiry,
        'instruction':
            'Scan this PNG during the MPO demo to trigger the rejection banner.',
      },
      'instructions':
          'Each PNG below encodes the GS1 DataMatrix on a single carton. '
          'Open them on a second device and point the MPO scanner at them '
          'one by one. The stray PNG will be refused on the channel.',
    };
  }

  /* ---------------------------------------------------------------------- */
  /* ZIP bundling                                                            */
  /* ---------------------------------------------------------------------- */

  /// Build the full QR ZIP and return its bytes.
  ///
  /// Per-carton filename pattern matches TS:
  /// `carton_NN_<sku>_<cartonId>.png`, zero-padded two-digit index. The stray
  /// uses `DEMO_STRAY_CARTON_REJECTION_TEST.png`. The `archive` 3.6 API uses
  /// `Archive.addFile(ArchiveFile)` for raw bytes and `ZipFileEncoder` for
  /// the deflate stream; we follow that.
  static Future<Uint8List> buildQrZip({
    required Invoice invoice,
    required List<Carton> cartons,
  }) async {
    final archive = Archive();

    for (var i = 0; i < cartons.length; i++) {
      final c = cartons[i];
      final idxStr = i.toString().padLeft(2, '0');
      final png = await renderQrPng(c.gs1);
      archive.addFile(
        ArchiveFile(
          'carton_${idxStr}_${c.sku}_${c.cartonId}.png',
          png.length,
          png,
        ),
      );
    }

    final strayPng = await renderQrPng(SeedData.foreignCartonGs1);
    archive.addFile(
      ArchiveFile(
        'DEMO_STRAY_CARTON_REJECTION_TEST.png',
        strayPng.length,
        strayPng,
      ),
    );

    final manifest = const JsonEncoder.withIndent('  ').convert(
      buildManifest(invoice: invoice, cartons: cartons),
    );
    final manifestBytes = utf8.encode(manifest);
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('archive: ZipEncoder returned null bytes');
    }
    return Uint8List.fromList(encoded);
  }

  /* ---------------------------------------------------------------------- */
  /* PDF rendering                                                           */
  /* ---------------------------------------------------------------------- */

  /// Render the invoice PDF: A4 portrait, invoice header, line items, totals.
  ///
  /// Reproducible: the same invoice gives the same bytes on any phone, at any
  /// time. That is what lets the ledger hold the PDF's hash from the moment
  /// the invoice is minted ([issuedHash]) and refuse to record any other file
  /// against it. Three things used to make every render different:
  ///
  ///   * the token's live state and anchor were printed on it, so the bytes
  ///     changed as the invoice moved through its life;
  ///   * the `pdf` package stamps a creation date into the info dictionary,
  ///     which it only writes when a title or author is given; and
  ///   * it writes a random document ID into the trailer ([_pinDocumentId]).
  ///
  /// Dates are Dhaka dates (UTC+6), not the phone's time zone.
  static Future<Uint8List> renderInvoicePdf({required Invoice invoice}) async {
    final dateFmt = DateFormat('d MMM yyyy');
    String dhakaDate(int ms) => dateFmt.format(
          DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
              .add(const Duration(hours: 6)),
        );
    final moneyFmt = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'BDT ',
      decimalDigits: 2,
    );
    final pharmacy =
        SeedData.pharmacies.where((p) => p.did == invoice.pharmacyDid);
    final billTo = pharmacy.isEmpty
        ? invoice.pharmacyDid
        : '${pharmacy.first.name}, ${pharmacy.first.territory}';

    // No title or author: either makes the package write a creation date.
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoice.invoiceId,
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Issued: ${dhakaDate(invoice.issuedAt)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Due: ${dhakaDate(invoice.dueDate)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    SeedData.manufacturer.name,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Ledger reference: ${invoice.tokenId}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Text(
            'This invoice is recorded on the LaMP ledger. A bank checks this '
            'file against that record before it finances the invoice; an '
            'altered copy will not pass.',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Bill to: $billTo',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['SKU', 'Description', 'Strength', 'Qty', 'Cartons', 'Unit', 'Line total'],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(50),
              3: const pw.FixedColumnWidth(35),
              4: const pw.FixedColumnWidth(45),
              5: const pw.FixedColumnWidth(70),
              6: const pw.FlexColumnWidth(2),
            },
            data: [
              for (final l in invoice.lineItems)
                [
                  l.sku,
                  l.name,
                  l.strength,
                  l.quantity.toString(),
                  l.cartons.toString(),
                  moneyFmt.format(l.unitPrice),
                  moneyFmt.format(l.lineValue),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 200,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                        moneyFmt.format(invoice.value),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL DUE',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        moneyFmt.format(invoice.value),
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Terms: ${invoice.termsDays} days',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Cartons: ${invoice.cartonCount}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = Uint8List.fromList(await doc.save());
    return _pinDocumentId(bytes, '${invoice.invoiceId}/${invoice.tokenId}');
  }

  /// Hash of the PDF issued for [invoice]: what the ledger records at mint.
  static Future<String> issuedHash(Invoice invoice) async =>
      hashBytes(await renderInvoicePdf(invoice: invoice));

  /// Replace the random `/ID` in the trailer with one derived from [seed].
  ///
  /// The package draws the ID from `Random.secure()` and exposes no way to set
  /// it. It is written as two 64-digit hex strings, `/ID[<…><…>]`; the
  /// replacement is the same length, so no byte offset in the file moves.
  static Uint8List _pinDocumentId(Uint8List bytes, String seed) {
    const marker = '/ID[<';
    final text = latin1.decode(bytes);
    final at = text.lastIndexOf(marker);
    if (at < 0) {
      throw StateError('Invoice PDF has no document ID to pin.');
    }
    final pinned = LaMPCrypto.sha256Hex(seed);
    final first = at + marker.length;
    final second = first + 64 + 2; // past `><`
    final out = Uint8List.fromList(bytes);
    for (var i = 0; i < 64; i++) {
      out[first + i] = pinned.codeUnitAt(i);
      out[second + i] = pinned.codeUnitAt(i);
    }
    return out;
  }

  /// Hash of the bytes produced by [renderInvoicePdf].
  ///
  /// Convenience for the manufacturer's "stage for anchor" flow — keeps the
  /// caller from having to know `crypto.sha256.convert` is the right API.
  static String hashBytes(Uint8List bytes) => LaMPCrypto.sha256HexBytes(bytes);
}
