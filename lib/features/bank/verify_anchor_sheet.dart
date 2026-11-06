// The bank's invoice-PDF check.
//
// Before financing, the bank confirms the PDF it was sent is the invoice the
// manufacturer issued, and records that on the ledger:
//
// 1. Choose the PDF (file picker).
// 2. Hash it on the phone and compare with `token.issuedDocumentHash`, the
//    hash the ledger took of the issued PDF when the invoice was minted.
// 3. On a match, "Record as checked" submits `anchorInvoiceDocument`, which
//    makes the same comparison again and refuses anything else.
//
// The comparison used to be against the *anchor*, which is empty until the
// bank anchors — so before that, every file "matched", including another
// invoice's PDF. The copy on the sheet was also the chaincode's own vocabulary
// (token ids, channel anchor, hashes); a bank officer sees plain words now.
//
// The sheet never finances: that is the Finance button on the bank's card.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/chain/crypto.dart';
import '../../core/constants/ledger_labels.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';

enum _Phase { idle, reading, matched, mismatched, recorded }

class VerifyAndAnchorSheet extends StatefulWidget {
  final LaMPState state;
  final String tokenId;
  final Msp activeBank;

  const VerifyAndAnchorSheet({
    super.key,
    required this.state,
    required this.tokenId,
    required this.activeBank,
  });

  @override
  State<VerifyAndAnchorSheet> createState() => _VerifyAndAnchorSheetState();
}

class _VerifyAndAnchorSheetState extends State<VerifyAndAnchorSheet> {
  _Phase _phase = _Phase.idle;
  String? _pickedSha;
  int? _pickedLength;
  String? _pickedName;
  String? _problem;
  bool _recording = false;

  ReceivableToken? get _token => widget.state.viewFor(widget.tokenId)?.token;

  @override
  void initState() {
    super.initState();
    if (_token?.documentHash != null) _phase = _Phase.recorded;
  }

  Future<void> _choosePdf() async {
    setState(() {
      _phase = _Phase.reading;
      _problem = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _phase = _restingPhase());
        return;
      }
      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) {
        setState(() {
          _phase = _restingPhase();
          _problem = "Couldn't read that file. Try choosing it again.";
        });
        return;
      }

      final sha = LaMPCrypto.sha256HexBytes(bytes);
      final issued = _token?.issuedDocumentHash;
      setState(() {
        _pickedSha = sha;
        _pickedLength = bytes.length;
        _pickedName = picked.name;
        if (issued == null) {
          _phase = _Phase.idle;
          _problem = "The manufacturer hasn't issued this invoice's PDF yet, "
              'so there is nothing to check it against. Ask them to send it '
              'from the app.';
        } else if (issued.toLowerCase() == sha.toLowerCase()) {
          _phase = _token?.documentHash != null ? _Phase.recorded : _Phase.matched;
        } else {
          _phase = _Phase.mismatched;
        }
      });
    } catch (e) {
      debugPrint('VerifyAndAnchorSheet: picking failed ($e)');
      setState(() {
        _phase = _restingPhase();
        _problem = "Couldn't open the file picker. Try again.";
      });
    }
  }

  _Phase _restingPhase() =>
      _token?.documentHash != null ? _Phase.recorded : _Phase.idle;

  Future<void> _record() async {
    final sha = _pickedSha;
    final len = _pickedLength;
    final name = _pickedName;
    if (sha == null || len == null || name == null) return;
    setState(() {
      _recording = true;
      _problem = null;
    });
    final res = await widget.state.anchorInvoiceDocument(
      widget.tokenId,
      widget.activeBank,
      sha256: sha,
      byteLength: len,
      filename: name,
    );
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (res.ok) {
        _phase = _Phase.recorded;
      } else {
        _problem = LedgerLabels.reason(res.error);
      }
    });
  }

  /// Share the issued invoice PDF. It is reproducible, so these are the same
  /// bytes the manufacturer issued and the ledger recorded the hash of.
  Future<void> _sharePdf() async {
    try {
      final pdf = await widget.state.generateInvoicePdf(widget.tokenId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${pdf.filename}');
      await file.writeAsBytes(pdf.bytes);
      await Share.shareXFiles(
        [XFile(file.path, name: pdf.filename, mimeType: 'application/pdf')],
        subject: 'Invoice ${pdf.filename}',
      );
    } catch (e) {
      debugPrint('VerifyAndAnchorSheet: sharing failed ($e)');
      if (!mounted) return;
      setState(() => _problem = "Couldn't share the invoice PDF. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final invoiceId = _token?.invoiceId ?? widget.tokenId;
    final recorded = _token?.documentHash != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Gap.md),
                  decoration: BoxDecoration(
                    color: c.lineStrong,
                    borderRadius: BorderRadius.circular(LaMPRadius.pill),
                  ),
                ),
              ),
              Text('Check the invoice PDF', style: LaMPType.head.copyWith(color: c.ink)),
              const SizedBox(height: Gap.xs),
              Text(invoiceId, style: LaMPType.monoMicro.copyWith(color: c.inkFaint)),
              const SizedBox(height: Gap.lg),
              _line(
                context,
                label: 'Status',
                value: recorded ? 'Checked and recorded' : 'Not checked yet',
                color: recorded ? c.verified : c.pending,
              ),
              if (_pickedName != null) ...[
                const SizedBox(height: Gap.xs),
                _line(
                  context,
                  label: 'Your file',
                  value: _pickedName!,
                  color: _phase == _Phase.mismatched ? c.dispute : c.ink,
                ),
              ],
              const SizedBox(height: Gap.lg),
              _verdict(context, invoiceId),
              if (_problem != null) ...[
                const SizedBox(height: Gap.sm),
                Text(_problem!, style: LaMPType.caption.copyWith(color: c.dispute)),
              ],
              const SizedBox(height: Gap.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('verify-pick'),
                      icon: const Icon(Icons.upload_file, size: IconSize.sm),
                      label: const Text('Choose PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.brand,
                        side: BorderSide(color: c.lineStrong),
                        padding: const EdgeInsets.symmetric(vertical: Gap.md),
                      ),
                      onPressed: _phase == _Phase.reading ? null : _choosePdf,
                    ),
                  ),
                  if (_phase == _Phase.matched) ...[
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('verify-anchor'),
                        icon: _recording
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.task_alt, size: IconSize.sm),
                        label: Text(_recording ? 'Recording…' : 'Record as checked'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.brand,
                          foregroundColor: c.onBrand,
                          padding: const EdgeInsets.symmetric(vertical: Gap.md),
                        ),
                        onPressed: _recording ? null : _record,
                      ),
                    ),
                  ],
                ],
              ),
              if (recorded) ...[
                const SizedBox(height: Gap.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('verify-download'),
                    icon: const Icon(Icons.ios_share, size: IconSize.sm),
                    label: const Text('Share invoice PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.brand,
                      side: BorderSide(color: c.lineStrong),
                      padding: const EdgeInsets.symmetric(vertical: Gap.md),
                    ),
                    onPressed: _sharePdf,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _verdict(BuildContext context, String invoiceId) {
    final c = context.lamp;
    return switch (_phase) {
      _Phase.idle => _banner(
          context,
          icon: Icons.info_outline,
          color: c.inkMuted,
          text: 'Choose the PDF the manufacturer sent you. We check it '
              'against the invoice recorded on the ledger.',
        ),
      _Phase.reading => _banner(
          context,
          icon: Icons.hourglass_top,
          color: c.pending,
          text: 'Checking the file…',
        ),
      _Phase.matched => _banner(
          context,
          icon: Icons.verified,
          color: c.verified,
          text: 'This is the invoice the manufacturer issued. Record it as '
              'checked to finance.',
        ),
      _Phase.mismatched => _banner(
          context,
          icon: Icons.dangerous,
          color: c.dispute,
          text: "This PDF isn't the invoice issued for $invoiceId. It may be "
              'another invoice or an altered copy. Ask the manufacturer to '
              'send it again.',
        ),
      _Phase.recorded => _banner(
          context,
          icon: Icons.verified,
          color: c.verified,
          text: 'Checked and recorded. You can finance this invoice now.',
        ),
    };
  }

  Widget _banner(BuildContext context,
      {required IconData icon, required Color color, required String text}) {
    final c = context.lamp;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LaMPRadius.control),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: IconSize.sm, color: color),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(text, style: LaMPType.caption.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context,
      {required String label, required String value, required Color color}) {
    final c = context.lamp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: LaMPType.caption.copyWith(color: c.inkFaint)),
        ),
        Expanded(
          child: Text(value, style: LaMPType.caption.copyWith(color: color)),
        ),
      ],
    );
  }
}
