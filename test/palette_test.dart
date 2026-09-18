import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lamp_flutter/core/constants/palette.dart';

/// Guards the theme migration.
///
/// The layout sweep checks that a screen fits. It cannot tell that a screen
/// fits and is the wrong colour — which is exactly what happened here: bank,
/// manufacturer and MPO passed every layout check while painting a fixed dark
/// palette that ignored the toggle entirely. Pharmacy rendered light and bank
/// rendered dark in the same session.
///
/// A screen that names `LaMPColors.portalInk` has opted out of theming, so the
/// check is simply that no screen names one.
void main() {
  group('screens and widgets resolve colour from the theme', () {
    // Widgets are covered as well as screens. The first version of this guard
    // checked `lib/features` only, which let RecourseDial and PrivateSeal keep
    // an `isDark` flag — a second source of truth for something the ambient
    // theme already knows.
    final sources = [
      ...Directory('lib/features').listSync(recursive: true),
      ...Directory('lib/widgets').listSync(recursive: true),
    ]
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // The camera sheet paints its own chrome over a live preview, where
        // white-on-black is the only thing that reads regardless of theme.
        .where((f) => !f.path.endsWith('carton_scanner_sheet.dart'));

    for (final file in sources) {
      final name = file.uri.pathSegments.last;

      test('$name names no world-specific colour', () {
        final offenders = <String>[];
        final lines = file.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;

          if (line.contains('LaMPColors.portal') ||
              line.contains('LaMPColors.field') ||
              line.contains('Color(0xFF131B17)') ||
              // A flag that says which theme is in force is the same mistake
              // as a hardcoded colour: it can disagree with the theme.
              line.contains('isDark')) {
            offenders.add('  ${i + 1}: ${line.trim()}');
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'These read a fixed palette instead of context.lamp, so they '
              'will not follow the theme:\n${offenders.join('\n')}',
        );
      });
    }
  });

  test('every palette keeps body text readable', () {
    // 4.5:1 is the floor for normal text. Secondary text is held to it too:
    // inkMuted carries real content, not decoration.
    final palettes = {
      'field light': LampPalette.fieldLight,
      'field dark': LampPalette.fieldDark,
      'portal light': LampPalette.portalLight,
      'portal dark': LampPalette.portalDark,
    };

    final failures = <String>[];

    palettes.forEach((name, p) {
      for (final entry in {'ink': p.ink, 'inkMuted': p.inkMuted}.entries) {
        for (final ground in {'bg': p.bg, 'surface': p.surface}.entries) {
          final ratio = _contrast(entry.value, ground.value);
          if (ratio < 4.5) {
            failures.add(
              '$name: ${entry.key} on ${ground.key} is '
              '${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      }
    });

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : _pow((s + 0.055) / 1.055, 2.4);
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _pow(double x, double e) {
  // Small integer-free power, to keep this file dependency-free.
  return _exp(e * _ln(x));
}

double _ln(double x) {
  var result = 0.0;
  var value = x;
  while (value > 2) {
    value /= 2;
    result += 0.6931471805599453;
  }
  while (value < 1) {
    value *= 2;
    result -= 0.6931471805599453;
  }
  final z = (value - 1) / (value + 1);
  var term = z;
  final z2 = z * z;
  for (var n = 1; n < 40; n += 2) {
    result += 2 * term / n;
    term *= z2;
  }
  return result;
}

double _exp(double x) {
  var sum = 1.0;
  var term = 1.0;
  for (var n = 1; n < 40; n++) {
    term *= x / n;
    sum += term;
  }
  return sum;
}
