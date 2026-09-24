import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the design system. Any new screen under lib/features or
/// lib/widgets that bypasses the tokens fails here, so consistency does not
/// depend on anyone remembering the rules.
///
/// Allowed homes for raw values: lib/core/constants/, lib/core/design/.
void main() {
  final roots = ['lib/features', 'lib/widgets'];
  final files = roots
      .expand((r) => Directory(r).listSync(recursive: true))
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final rules = <String, RegExp>{
    // `(?<!\w)` so `LaMPColors.bKash` — the logo exception below — does not
    // also match as `Colors.bKash`.
    'raw colour — use context.lamp.*': RegExp(r'Color\(0x|(?<!\w)Colors\.(?!transparent\b)\w+'),
    'inline font size — use a LaMPType style': RegExp(r'fontSize\s*:'),
    'bold/w700/w800/w900 — weights are 400/500/600': RegExp(r'FontWeight\.(bold|w[789]00)'),
    'legacy LaMPColors — use context.lamp.* (bKash/nagad logos excepted)':
        RegExp(r'LaMPColors\.(?!bKash\b|nagad\b)\w+'),
    'raw TextStyle( — start from LaMPType.x.copyWith': RegExp(r'(?<![\w.])TextStyle\('),
    'inline fontFamily — families live in LaMPType': RegExp(r'fontFamily\s*:'),
    'brightness branch — the palette already resolves per theme':
        RegExp(r'brightness\s*==\s*Brightness\.(dark|light)'),
  };

  // lamp_mark.dart legitimately picks an asset per brightness.
  const brightnessExempt = {'lamp_mark.dart', 'theme_toggle.dart'};

  for (final entry in rules.entries) {
    test(entry.key, () {
      final hits = <String>[];
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        if (entry.key.startsWith('brightness') && brightnessExempt.contains(name)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (l.trimLeft().startsWith('//')) continue;
          if (l.contains('// design-lint: allow')) continue;
          if (entry.value.hasMatch(l)) hits.add('${f.path}:${i + 1}  ${l.trim()}');
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}');
    });
  }
}
