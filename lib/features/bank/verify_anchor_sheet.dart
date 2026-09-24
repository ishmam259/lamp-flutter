// Verify-and-anchor modal sheet for the bank.
//
// Bank-side analog of `LaMP/components/invoice-document.tsx` `mode="verify"`:
// 1. Pick a PDF (file picker).
// 2. SHA-256 it locally and compare against the channel anchor (`token.documentHash`).
//    - Match → green banner + "Anchor to the channel" button (only shown when
//      the token isn't already anchored).
//    - Mismatch → red banner with both digests so the financier can see which
//      file they got.
// 3. Once anchored, the verdict turns into a green "anchored at block N by
//    MeghnaMSP" banner and a "Download PDF" button surfaces the same bytes
//    the manufacturer staged (or any future PDF the financier verifies).
//
// The sheet never fires `matchAndAdvance` itself — that's the separate Finance
// button on the opportunity card. The sheet only writes the document anchor.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/chain/crypto.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/typography.dart';
import '../../core/models/domain_models.dart';
import '../../core/state/lamp_state.dart';

/// Verdict state held by the sheet — drives both the banner colour and which
/// action button is enabled.
enum _VerifyPhase { idle, hashing, matched, mismatched, anchored }

class _VerifyOutcome {
  final String? sha256;
  final int? byteLength;
  final String? filename;
  final String? error;

  const _VerifyOutcome({
    this.sha256,
    this.byteLength,
    this.filename,
    this.error,
  });
}

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
  _VerifyPhase _phase = _VerifyPhase.idle;
  _VerifyOutcome _outcome = const _VerifyOutcome();
  String? _anchorError;
  bool _isAnchoring = false;

  ReceivableToken? _token() {
    return widget.state.viewFor(widget.tokenId)?.token;
  }

  Future<void> _pickAndHash() async {
    setState(() {
      _phase = _VerifyPhase.hashing;
      _outcome = const _VerifyOutcome();
      _anchorError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _phase = _VerifyPhase.idle);
        return;
      }
      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path != null
              ? await File(picked.path!).readAsBytes()
              : null);
      if (bytes == null) {
        setState(() {
          _phase = _VerifyPhase.idle;
          _outcome = const _VerifyOutcome(
            error: 'Could not read the picked file.',
          );
        });
        return;
      }

      final sha = LaMPCrypto.sha256HexBytes(bytes);
      final token = _token();
      final expected = token?.documentHash;

      setState(() {
        _outcome = _VerifyOutcome(
          sha256: sha,
          byteLength: bytes.length,
          filename: picked.name,
        );
        if (expected != null &&
            expected.toLowerCase() == sha.toLowerCase()) {
          _phase = _VerifyPhase.anchored;
        } else if (expected == null) {
          // Not yet anchored on chain; pick succeeded; await user click on
          // "Anchor to the channel". Stay in "matched" so the banner is green
          // and the anchor button is enabled.
          _phase = _VerifyPhase.matched;
        } else {
          _phase = _VerifyPhase.mismatched;
        }
      });
    } catch (e) {
      setState(() {
        _phase = _VerifyPhase.idle;
        _outcome = _VerifyOutcome(error: e.toString());
      });
    }
  }

  Future<void> _anchorOnChain() async {
    final sha = _outcome.sha256;
    final len = _outcome.byteLength;
    final fname = _outcome.filename;
    if (sha == null || len == null || fname == null) return;
    setState(() {
      _isAnchoring = true;
      _anchorError = null;
    });
    final res = await widget.state.anchorInvoiceDocument(
      widget.tokenId,
      widget.activeBank,
      sha256: sha,
      byteLength: len,
      filename: fname,
    );
    if (!mounted) return;
    setState(() {
      _isAnchoring = false;
      if (res.ok) {
        _phase = _VerifyPhase.anchored;
      } else {
        _anchorError = res.error ?? 'Anchor transaction failed.';
      }
    });
  }

  Future<void> _downloadAnchoredPdf() async {
    final bytes = widget.state.anchoredDocumentBytes(widget.tokenId);
    final doc = widget.state.getAnchoredDocument(widget.tokenId);
    if (bytes == null || doc == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${doc.filename}');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, name: doc.filename, mimeType: 'application/pdf')],
      subject: 'LaMP anchored invoice ${doc.filename}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lamp;
    final token = _token();
    final tokenDocHash = token?.documentHash;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: c.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Verify anchored invoice PDF',
                style: LaMPType.head.copyWith(color: c.ink),

              ),
              const SizedBox(height: 4),
              Text(
                'Token ${widget.tokenId}',
                style: LaMPType.monoMicro.copyWith(color: c.inkFaint),

              ),
              const SizedBox(height: 16),
              _ledgerLine(
                context,
                label: 'Channel anchor',
                value: tokenDocHash == null
                    ? '— not anchored —'
                    : 'SHA-256 ${tokenDocHash.substring(0, 16)}…',
                color: tokenDocHash == null ? c.pending : c.verified,
              ),
              if (_outcome.sha256 != null) ...[
                const SizedBox(height: 6),
                _ledgerLine(
                  context,
                  label: 'Picked file',
                  value:
                      'SHA-256 ${_outcome.sha256!.substring(0, 16)}… · '
                      '${_outcome.byteLength} bytes · ${_outcome.filename}',
                  color: _phase == _VerifyPhase.mismatched
                      ? c.dispute
                      : c.brand,
                ),
              ],
              const SizedBox(height: 16),
              _verdictBanner(context),
              if (_anchorError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _anchorError!,
                  style: LaMPType.caption.copyWith(color: c.dispute),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('verify-pick'),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Pick PDF & hash'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.brand,
                        side: BorderSide(color: c.lineStrong),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _phase == _VerifyPhase.hashing
                          ? null
                          : _pickAndHash,
                    ),
                  ),
                  if (_phase == _VerifyPhase.matched) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('verify-anchor'),
                        icon: _isAnchoring
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link, size: 16),
                        label: Text(
                          _isAnchoring ? 'Anchoring...' : 'Anchor to channel',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.brand,
                          foregroundColor: c.onBrand,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isAnchoring ? null : _anchorOnChain,
                      ),
                    ),
                  ],
                ],
              ),
              if (tokenDocHash != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('verify-download'),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download anchored PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.brand,
                      side: BorderSide(color: c.lineStrong),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _downloadAnchoredPdf,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _verdictBanner(BuildContext context) {
    final c = context.lamp;
    switch (_phase) {
      case _VerifyPhase.idle:
        if (_outcome.error != null) {
          return _banner(
            context,
            icon: Icons.error_outline,
            color: c.dispute,
            text: _outcome.error!,
          );
        }
        return _banner(
          context,
          icon: Icons.info_outline,
          color: c.inkMuted,
          text: 'Pick the PDF the manufacturer sent. We\'ll hash it locally '
              'and compare against the channel anchor.',
        );
      case _VerifyPhase.hashing:
        return _banner(
          context,
          icon: Icons.hourglass_top,
          color: c.pending,
          text: 'Reading and hashing the picked file…',
        );
      case _VerifyPhase.matched:
        return _banner(
          context,
          icon: Icons.verified,
          color: c.verified,
          text: 'Hash matches — anchor it to the channel to finance.',
        );
      case _VerifyPhase.mismatched:
        return _banner(
          context,
          icon: Icons.dangerous,
          color: c.dispute,
          text: 'Hash mismatch. The picked file is not the one this invoice '
              'is anchored to. Compare digests above.',
        );
      case _VerifyPhase.anchored:
        return _banner(
          context,
          icon: Icons.verified,
          color: c.verified,
          text: 'Anchored to the channel. Finance button is now enabled.',
        );
    }
  }

  Widget _banner(BuildContext context,
      {required IconData icon, required Color color, required String text}) {
    final c = context.lamp;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: LaMPType.caption.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerLine(BuildContext context,
      {required String label, required String value, required Color color}) {
    final c = context.lamp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: LaMPType.caption.copyWith(color: c.inkFaint),

          ),
        ),
        Expanded(
          child: Text(
            value,
            style: LaMPType.monoMicro.copyWith(color: color),

          ),
        ),
      ],
    );
  }
}
