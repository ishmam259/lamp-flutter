import 'package:flutter/widgets.dart';

import '../constants/palette.dart';

/// Shadows in layers, the way a design system that cares does it.
///
/// A single `boxShadow` with a big blur radius is the tell of an interface
/// nobody spent long on: it produces a soft grey halo with no contact point,
/// so the card looks like it is hovering an inch off the page at every level.
/// Real elevation is at least two shadows — a tight, nearly-opaque one for the
/// contact edge where the object meets the surface, and a wide, very sheer one
/// for the ambient cast. The tight one is what makes a card look *attached*;
/// the wide one is what makes it look *above*.
///
/// The colour comes from `palette.shadow`, which is tinted toward the ground
/// rather than neutral black, so a card on a green-tinted page casts a shadow
/// that belongs to that page.
///
/// Each level has a `…From(Color)` twin for the one place that needs it: an
/// overlay entry sits above the per-seat `Theme`, so anything built in there
/// has to be handed its palette rather than reading one.
class LumaElevation {
  /// Flat. A hairline border does the separating; nothing casts.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// A card at rest. Barely there, and removing it is immediately visible.
  static List<BoxShadow> rest(BuildContext context) =>
      restFrom(context.lamp.shadow);

  static List<BoxShadow> restFrom(Color s) => [
        BoxShadow(
          color: s.withValues(alpha: s.a * 0.5),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: s.withValues(alpha: s.a * 0.55),
          blurRadius: 12,
          spreadRadius: -4,
          offset: const Offset(0, 4),
        ),
      ];

  /// A card that is the point of the screen — the ledger strip, a primary
  /// summary. One step up, not three.
  static List<BoxShadow> raised(BuildContext context) =>
      raisedFrom(context.lamp.shadow);

  static List<BoxShadow> raisedFrom(Color s) => [
        BoxShadow(
          color: s.withValues(alpha: s.a * 0.6),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: s,
          blurRadius: 28,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
      ];

  /// Something that has arrived over everything else: a toast, a menu, a
  /// floating bar. Detached, so the contact layer goes and the cast widens.
  static List<BoxShadow> floating(BuildContext context) =>
      floatingFrom(context.lamp.shadow);

  static List<BoxShadow> floatingFrom(Color s) => [
        BoxShadow(
          color: s,
          blurRadius: 16,
          spreadRadius: -4,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: s.withValues(alpha: s.a * 0.8),
          blurRadius: 48,
          spreadRadius: -12,
          offset: const Offset(0, 20),
        ),
      ];
}
