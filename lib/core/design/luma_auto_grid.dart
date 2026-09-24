import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// `grid-template-columns: repeat(auto-fit, minmax(min, 1fr)); gap: g;`
///
/// The CSS rule reads as one line and does something a media query cannot: it
/// asks how many columns of at least `min` fit in the space actually
/// available, then divides the space evenly between however many that turns
/// out to be. No breakpoints are named, so there is no width at which the
/// layout is wrong because nobody thought to write a rule for it.
///
/// Flutter's `GridView` asks for the opposite inputs. `crossAxisCount` makes
/// the caller do the arithmetic, and `SliverGridDelegateWithMaxCrossAxisExtent`
/// fixes a *maximum* and needs a `childAspectRatio` — a number no card has,
/// because a card is as tall as its text. This lays out the same way CSS does:
/// count columns from the minimum, then let each row be as tall as its tallest
/// cell and stretch the rest to match.
///
/// ```dart
/// LumaAutoGrid(
///   minColumnWidth: 240,
///   gap: Gap.md,
///   children: seats,
/// )
/// ```
///
/// On a 360dp phone that is one column. On a 768dp tablet it is two or three.
/// Nobody wrote either number.
class LumaAutoGrid extends StatelessWidget {
  final List<Widget> children;

  /// The `minmax()` floor: no column is narrower than this, and the count
  /// drops rather than letting one get smaller.
  final double minColumnWidth;

  /// `gap` — between columns and between rows alike, as in CSS. Grid gap does
  /// not collapse and is not a margin, so there is no edge gutter to strip off
  /// the outside afterwards.
  final double gap;

  /// CSS grid's `align-items: stretch`: every cell in a row takes the height
  /// of the tallest, so a row of cards has one bottom edge rather than a
  /// ragged one. Turn it off for tiles that are uniform anyway.
  final bool equalRowHeight;

  /// Caps the column count regardless of how much room there is. A grid of
  /// three seats on a 1400dp desktop should be three wide, not seven.
  final int? maxColumns;

  const LumaAutoGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 200,
    this.gap = 12,
    this.equalRowHeight = true,
    this.maxColumns,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;

        // Unbounded width has no column count to compute, so fall back to the
        // single column the caller would have got from a plain Column.
        int columns = 1;
        if (available.isFinite && available > 0) {
          // The CSS arithmetic: n columns of `min` need (n-1) gaps between
          // them, so n = floor((available + gap) / (min + gap)).
          columns = ((available + gap) / (minColumnWidth + gap)).floor();
        }
        columns = columns.clamp(1, children.length);
        if (maxColumns != null) columns = columns.clamp(1, maxColumns!);

        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final end = math.min(start + columns, children.length);
          if (start > 0) rows.add(SizedBox(height: gap));
          rows.add(
            _GridRow(
              columns: columns,
              gap: gap,
              stretch: equalRowHeight,
              children: [
                ...children.sublist(start, end),
                // The short last row keeps the column rhythm instead of
                // spreading two cards across the full width — `auto-fit` sizes
                // the tracks, not the items, so a row with a hole in it leaves
                // the hole where it is.
                for (var i = end; i < start + columns; i++)
                  const SizedBox.shrink(),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// One row of equal-width tracks, laid out twice.
///
/// The obvious way to write this is `Row(crossAxisAlignment: stretch)` inside
/// an `IntrinsicHeight`, and it works right up until a cell contains a
/// `LayoutBuilder` — which, in this app, every one of them does, because a
/// card that reflows to its own width is the point. `IntrinsicHeight` asks its
/// child how tall it would like to be, `LayoutBuilder` cannot answer that
/// without speculatively running a build, and Flutter throws rather than let
/// it try:
///
/// > LayoutBuilder does not support returning intrinsic dimensions.
///
/// Laying out is not the same as asking. This measures by *doing* the layout
/// with a loose height, takes the tallest result, and lays the row out again
/// with that height forced — two real passes instead of one speculative one.
/// A `LayoutBuilder` child is perfectly happy to be laid out twice.
///
/// The cost is one extra layout pass per row, paid only where a row has more
/// than one column, which on a phone is never.
class _GridRow extends MultiChildRenderObjectWidget {
  final int columns;
  final double gap;
  final bool stretch;

  const _GridRow({
    required this.columns,
    required this.gap,
    required this.stretch,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGridRow(columns: columns, gap: gap, stretch: stretch);

  @override
  void updateRenderObject(BuildContext context, _RenderGridRow renderObject) {
    renderObject
      ..columns = columns
      ..gap = gap
      ..stretch = stretch;
  }
}

class _GridRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGridRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridRowParentData> {
  _RenderGridRow({
    required int columns,
    required double gap,
    required bool stretch,
  })  : _columns = columns,
        _gap = gap,
        _stretch = stretch;

  int _columns;
  set columns(int v) {
    if (_columns == v) return;
    _columns = v;
    markNeedsLayout();
  }

  double _gap;
  set gap(double v) {
    if (_gap == v) return;
    _gap = v;
    markNeedsLayout();
  }

  bool _stretch;
  set stretch(bool v) {
    if (_stretch == v) return;
    _stretch = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridRowParentData) {
      child.parentData = _GridRowParentData();
    }
  }

  @override
  void performLayout() {
    // A row always takes the full width it is offered — these are grid
    // tracks, and a track that shrank to its content would not be one.
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.minWidth;
    final trackWidth =
        math.max(0.0, (width - _gap * (_columns - 1)) / _columns);

    // Pass one: every cell at its natural height, to find the tallest.
    double tallest = 0;
    var child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: trackWidth),
        parentUsesSize: true,
      );
      tallest = math.max(tallest, child.size.height);
      child = childAfter(child);
    }

    // Pass two: the same cells again, this time told how tall the row is.
    // Skipped entirely when nothing is stretching, so the common case still
    // costs one pass.
    child = firstChild;
    var x = 0.0;
    while (child != null) {
      if (_stretch && child.size.height != tallest) {
        child.layout(
          BoxConstraints.tightFor(width: trackWidth, height: tallest),
          parentUsesSize: true,
        );
      }
      (child.parentData! as _GridRowParentData).offset = Offset(x, 0);
      x += trackWidth + _gap;
      child = childAfter(child);
    }

    size = constraints.constrain(Size(width, tallest));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
