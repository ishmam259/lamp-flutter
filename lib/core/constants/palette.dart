import 'package:flutter/material.dart';

/// Semantic colour for one world in one theme.
///
/// LaMP has two axes, and they are independent:
///
///   **World** is a product decision. `portal` is the institutional instrument
///   panel — manufacturer, bank, regulator — dense and quiet, for someone who
///   sits in front of it all day. `field` is the rider's and the pharmacist's
///   phone: bigger targets, more air, fewer things per screen.
///
///   **Theme** is the person's choice, and now genuinely follows the system or
///   an explicit toggle. Before this, world and theme were welded together —
///   portals were always dark and field apps always light — so half of every
///   palette did not exist.
///
/// Widgets read these slots, never raw hex. That is what makes a theme switch
/// a one-line change rather than a hunt through eight thousand lines.
///
/// One rule survives from the web design system and is not negotiable:
/// **mint is reserved**. [verified] means "the ledger confirmed this" and
/// nothing else. It is never a call to action.
@immutable
class LampPalette extends ThemeExtension<LampPalette> {
  /// The page behind everything.
  final Color bg;

  /// Cards and sheets — the plane content sits on.
  final Color surface;

  /// A quieter card, for nesting one inside another.
  final Color surfaceAlt;

  /// Recessed wells: progress tracks, empty slots, inactive steps.
  final Color surfaceSunken;

  /// Primary text.
  final Color ink;

  /// Secondary text. Still passes 4.5:1 — this is not a decorative grey.
  final Color inkMuted;

  /// Labels and metadata. Large or non-essential text only.
  final Color inkFaint;

  final Color line;
  final Color lineStrong;

  /// The action colour. Buttons, links, selected state.
  final Color brand;

  /// Text and icons sitting on top of [brand].
  final Color onBrand;

  final Color brandSoft;

  /// Reserved: the ledger confirmed this.
  final Color verified;
  final Color verifiedSoft;

  /// In flight, awaiting, counting down.
  final Color pending;
  final Color pendingSoft;

  /// Refused, disputed, failed.
  final Color dispute;
  final Color disputeSoft;

  /// Chain provenance — hashes, blocks, endorsements.
  final Color chain;
  final Color chainSoft;

  /// Tinted to the ground rather than neutral black, so cards lift off the
  /// page instead of looking like they are sitting in a puddle.
  final Color shadow;

  const LampPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.verified,
    required this.verifiedSoft,
    required this.pending,
    required this.pendingSoft,
    required this.dispute,
    required this.disputeSoft,
    required this.chain,
    required this.chainSoft,
    required this.shadow,
  });

  /* ---------------------------------------------------------------------- */
  /* Field — the rider and the pharmacist                                    */
  /* ---------------------------------------------------------------------- */

  /// Sunlight-legible. Near-white ground, deep green action colour that stays
  /// readable at arm's length on a bright Bogura afternoon.
  static const LampPalette fieldLight = LampPalette(
    bg: Color(0xFFF6F8F6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF3F0),
    surfaceSunken: Color(0xFFE3E9E5),
    ink: Color(0xFF0C1411),
    inkMuted: Color(0xFF44544C),
    inkFaint: Color(0xFF6D7E76),
    line: Color(0xFFE0E6E2),
    lineStrong: Color(0xFFC7D2CC),
    brand: Color(0xFF0B5D42),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0x140B5D42),
    verified: Color(0xFF0F8A62),
    verifiedSoft: Color(0x1A0F8A62),
    pending: Color(0xFF9A6206),
    pendingSoft: Color(0x1A9A6206),
    dispute: Color(0xFFB92F36),
    disputeSoft: Color(0x16B92F36),
    chain: Color(0xFF2F5FA8),
    chainSoft: Color(0x162F5FA8),
    shadow: Color(0x1A0C1411),
  );

  /// The same app after dark — a rider finishing a run at night, a pharmacist
  /// closing up. Mint lifts to carry the action colour, because #0B5D42 on a
  /// dark ground is unreadable.
  static const LampPalette fieldDark = LampPalette(
    bg: Color(0xFF0B100E),
    // Lifted. A shadow cannot separate anything in dark mode — there is
    // nothing darker than the ground to cast onto — so the only thing that
    // makes a card read as a card is being lighter than the page. These were
    // within six points of the background and the interface looked like one
    // flat sheet with hairlines drawn on it.
    surface: Color(0xFF1A231E),
    surfaceAlt: Color(0xFF232E28),
    surfaceSunken: Color(0xFF2C3830),
    ink: Color(0xFFEAF1EC),
    inkMuted: Color(0xFFAEBDB5),
    inkFaint: Color(0xFF7D8E85),
    line: Color(0xFF2C3931),
    lineStrong: Color(0xFF3D4C43),
    brand: Color(0xFF3DDC97),
    onBrand: Color(0xFF05130D),
    brandSoft: Color(0x1F3DDC97),
    verified: Color(0xFF3DDC97),
    verifiedSoft: Color(0x1F3DDC97),
    pending: Color(0xFFE8A33D),
    pendingSoft: Color(0x1FE8A33D),
    dispute: Color(0xFFE5484D),
    disputeSoft: Color(0x1FE5484D),
    chain: Color(0xFF7BA6E8),
    chainSoft: Color(0x1F7BA6E8),
    shadow: Color(0x66000000),
  );

  /* ---------------------------------------------------------------------- */
  /* Portal — the desk                                                       */
  /* ---------------------------------------------------------------------- */

  /// Ported from the web design system's light portal scope, so the phone and
  /// the desktop portals agree.
  ///
  /// Brand is a deep teal so it never collides with `verified`, which is
  /// emerald. The "mint is reserved" rule survives across both portals — a
  /// tinted action button is visually distinct from a confirmation badge.
  static const LampPalette portalLight = LampPalette(
    // The page is no longer white. A white card on a white page is not a
    // card — it is a rectangle of border, and the whole light portal read as
    // a wireframe because of it. Luma's light mode is a faintly tinted
    // ground with white cards lifted off it, which is what makes elevation
    // do any work at all in light.
    bg: Color(0xFFF5F8F6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F8F5),
    surfaceSunken: Color(0xFFE5EFE8),
    ink: Color(0xFF070E0B),
    inkMuted: Color(0xFF2D3D35),
    inkFaint: Color(0xFF52675D),
    line: Color(0xFFE1EDE5),
    lineStrong: Color(0xFFC5DACF),
    brand: Color(0xFF0F766E),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0x1F0F766E),
    verified: Color(0xFF059669),
    verifiedSoft: Color(0x1F059669),
    pending: Color(0xFF925807),
    pendingSoft: Color(0x1C925807),
    dispute: Color(0xFFB92F36),
    disputeSoft: Color(0x1AB92F36),
    chain: Color(0xFF225698),
    chainSoft: Color(0x1A225698),
    shadow: Color(0x14070E0B),
  );

  /// The default for the institutional seats.
  ///
  /// Brand and `verified` share the mint, which is the Luma palette as drawn.
  /// A primary action and a confirmation mark therefore read the same colour;
  /// that trade was taken deliberately in favour of the Luma identity.
  static const LampPalette portalDark = LampPalette(
    bg: Color(0xFF090D0C),
    surface: Color(0xFF17211C),
    surfaceAlt: Color(0xFF202B25),
    surfaceSunken: Color(0xFF2A3730),
    ink: Color(0xFFE9F0EB),
    inkMuted: Color(0xFFAFBEB6),
    inkFaint: Color(0xFF7C8A85),
    line: Color(0xFF2A3630),
    lineStrong: Color(0xFF3A4941),
    brand: Color(0xFF3DDC97),
    onBrand: Color(0xFF04120C),
    brandSoft: Color(0x1F3DDC97),
    verified: Color(0xFF3DDC97),
    verifiedSoft: Color(0x1F3DDC97),
    pending: Color(0xFFE8A33D),
    pendingSoft: Color(0x1FE8A33D),
    dispute: Color(0xFFE5484D),
    disputeSoft: Color(0x1FE5484D),
    chain: Color(0xFF7BA6E8),
    chainSoft: Color(0x1F7BA6E8),
    shadow: Color(0x80000000),
  );

  static LampPalette resolve(LampWorld world, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (world) {
      LampWorld.field => dark ? fieldDark : fieldLight,
      LampWorld.portal => dark ? portalDark : portalLight,
    };
  }

  @override
  LampPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? line,
    Color? lineStrong,
    Color? brand,
    Color? onBrand,
    Color? brandSoft,
    Color? verified,
    Color? verifiedSoft,
    Color? pending,
    Color? pendingSoft,
    Color? dispute,
    Color? disputeSoft,
    Color? chain,
    Color? chainSoft,
    Color? shadow,
  }) {
    return LampPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandSoft: brandSoft ?? this.brandSoft,
      verified: verified ?? this.verified,
      verifiedSoft: verifiedSoft ?? this.verifiedSoft,
      pending: pending ?? this.pending,
      pendingSoft: pendingSoft ?? this.pendingSoft,
      dispute: dispute ?? this.dispute,
      disputeSoft: disputeSoft ?? this.disputeSoft,
      chain: chain ?? this.chain,
      chainSoft: chainSoft ?? this.chainSoft,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  LampPalette lerp(ThemeExtension<LampPalette>? other, double t) {
    if (other is! LampPalette) return this;
    return LampPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      verifiedSoft: Color.lerp(verifiedSoft, other.verifiedSoft, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      pendingSoft: Color.lerp(pendingSoft, other.pendingSoft, t)!,
      dispute: Color.lerp(dispute, other.dispute, t)!,
      disputeSoft: Color.lerp(disputeSoft, other.disputeSoft, t)!,
      chain: Color.lerp(chain, other.chain, t)!,
      chainSoft: Color.lerp(chainSoft, other.chainSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

enum LampWorld { field, portal }

/// `context.lamp.ink` — short enough that reaching for a raw hex is never the
/// path of least resistance.
extension LampPaletteAccess on BuildContext {
  LampPalette get lamp =>
      Theme.of(this).extension<LampPalette>() ?? LampPalette.portalDark;
}

/// The 4/8dp rhythm. Named so a screen cannot invent 13.
class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 40;

  /// Inside a card.
  ///
  /// Its own token rather than a reuse of [lg], because card padding is the
  /// single number that decides whether an interface feels considered or
  /// cramped, and it should be changeable without moving every other gap in
  /// the app with it. 16 was the old value and it put the text hard against
  /// the border; Luma's cards sit nearer 20-24.
  static const double card = 20;

  /// Between one group of content and the next. Sections separated by the
  /// same gap that separates two cards inside a section do not read as
  /// sections at all.
  static const double group = 36;
}

/// Icon sizes as tokens. There were ten arbitrary values before this, with
/// 16, 18 and 20 doing the same job in thirty-seven places.
class IconSize {
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}
