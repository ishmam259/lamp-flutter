import 'package:flutter/widgets.dart';

/// Container queries, ported.
///
/// The observation behind CSS `container-type: inline-size` is that a
/// component almost never wants to know the size of the *window*. A seat card
/// sits in a full-width list on a phone, in one column of a two-column grid on
/// a tablet, and inside a bottom sheet that is narrower than either. Asked
/// "how much room do I have", the honest answer is the width of its own box,
/// and `MediaQuery.sizeOf` cannot give that answer — it will happily report
/// 1024 to a card that has been handed 300.
///
/// Flutter's [LayoutBuilder] knows the right number but only hands it to the
/// widget directly underneath, so anything nested has to have it threaded
/// through by hand. [LumaContainer] measures once and publishes the result
/// down the tree, which is what `@container` does: declare the query root
/// here, read it from anywhere inside.
///
/// ```dart
/// LumaContainer(
///   child: Builder(builder: (context) {
///     return context.lumaWidth.isAtLeast(LumaWidth.regular)
///         ? const _WideLayout()
///         : const _StackedLayout();
///   }),
/// )
/// ```
enum LumaWidth {
  /// Under 380 — a phone column, a narrow sheet, one cell of a dense grid.
  /// One thing per line; nothing sits beside anything else.
  compact,

  /// 380–599 — a comfortable phone, a half-width tablet pane. A label and its
  /// value can share a line.
  regular,

  /// 600–899 — a tablet column or a wide sheet. Cards may go horizontal:
  /// leading art beside the text rather than above it.
  wide,

  /// 900 and up — a desk. Two content columns become reasonable.
  expansive;

  bool isAtLeast(LumaWidth other) => index >= other.index;

  /// The breakpoints, in one place. Changing a boundary here changes it for
  /// every component that reads a container, which is the property the CSS
  /// version has and a scatter of `if (width > 600)` does not.
  static LumaWidth of(double width) {
    if (width >= 900) return LumaWidth.expansive;
    if (width >= 600) return LumaWidth.wide;
    if (width >= 380) return LumaWidth.regular;
    return LumaWidth.compact;
  }
}

/// Declares a container query root, and publishes its measurement inside.
///
/// Cheap to nest: a screen declares one, a sheet inside it declares another,
/// and a card in the sheet reads the sheet's width rather than the screen's,
/// because the nearest one wins. That is the whole behaviour, and it is why a
/// component written against this needs no `isTablet` argument passed in from
/// its parent.
class LumaContainer extends StatelessWidget {
  final Widget child;

  /// Set when the query root is not the thing being laid out — a padded list,
  /// say, where the card's real box is narrower than the viewport by its
  /// horizontal padding. Without it the card would query a width it will never
  /// actually be given.
  final double widthAdjustment;

  const LumaContainer({
    super.key,
    required this.child,
    this.widthAdjustment = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded width — inside a horizontal scroller, or a Row that has
        // not been Expanded — measures as infinity, and every comparison
        // against it is true. Falling back to compact keeps a broken
        // measurement from silently producing the widest layout.
        final raw = constraints.maxWidth;
        final width = raw.isFinite ? (raw - widthAdjustment).clamp(0.0, raw) : 0.0;

        return _LumaContainerScope(
          width: width,
          size: LumaWidth.of(width),
          child: child,
        );
      },
    );
  }
}

class _LumaContainerScope extends InheritedWidget {
  final double width;
  final LumaWidth size;

  const _LumaContainerScope({
    required this.width,
    required this.size,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LumaContainerScope old) =>
      old.size != size || old.width != width;
}

extension LumaContainerAccess on BuildContext {
  /// The size class of the nearest [LumaContainer].
  ///
  /// With no container above it this falls back to the window, which keeps a
  /// component usable before its screen has been wrapped rather than throwing
  /// — but the fallback is the thing containers exist to avoid, so a component
  /// that reflows should sit under one.
  LumaWidth get lumaWidth {
    final scope = dependOnInheritedWidgetOfExactType<_LumaContainerScope>();
    return scope?.size ?? LumaWidth.of(MediaQuery.sizeOf(this).width);
  }

  /// The measured width in logical pixels, for the rare case where a size
  /// class is too coarse — sizing a cover image to a ratio, say.
  double get lumaContainerWidth {
    final scope = dependOnInheritedWidgetOfExactType<_LumaContainerScope>();
    return scope?.width ?? MediaQuery.sizeOf(this).width;
  }
}
