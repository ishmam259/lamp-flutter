import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lamp_flutter/core/design/luma_auto_grid.dart';
import 'package:lamp_flutter/core/design/luma_container.dart';

/// The two layout primitives this branch adds, tested at the level they make
/// promises at.
///
/// Both replace something Flutter ships, and both do it because the shipped
/// version asks for the wrong input — a column count instead of a minimum
/// width, a window size instead of a box size. A test that only checked "it
/// renders" would pass against either, so these check the arithmetic and the
/// measurement directly.

/// Lays a widget out at an exact window size, with no theme or scaffold in
/// the way to contribute padding of its own.
Future<void> _pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 2000)),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

void main() {
  group('LumaAutoGrid counts columns the way auto-fit does', () {
    // n = floor((available + gap) / (min + gap)), the same arithmetic the
    // browser runs for repeat(auto-fit, minmax(min, 1fr)).
    Widget grid(int count) => LumaAutoGrid(
          minColumnWidth: 240,
          gap: 12,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(key: ValueKey(i), height: 40),
          ],
        );

    /// The x offsets of the cells, rounded, in child order.
    List<double> columnsAt(WidgetTester tester, int count) => [
          for (var i = 0; i < count; i++)
            tester.getTopLeft(find.byKey(ValueKey(i))).dx,
        ];

    testWidgets('one column on a phone', (tester) async {
      await _pumpAt(tester, 360, grid(3));
      // Three cells, all flush left, so they are stacked.
      expect(columnsAt(tester, 3), everyElement(0.0));
    });

    testWidgets('two columns on a small tablet', (tester) async {
      await _pumpAt(tester, 620, grid(3));
      final xs = columnsAt(tester, 3);
      // 620 fits two 240s with a 12 gap and not three.
      expect(xs[0], 0.0);
      expect(xs[1], greaterThan(0.0));
      // The third wraps to the next row, back at the left edge.
      expect(xs[2], 0.0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(2))).dy,
        greaterThan(0.0),
      );
    });

    testWidgets('three columns at 992, and no more than the children',
        (tester) async {
      await _pumpAt(tester, 992, grid(3));
      final xs = columnsAt(tester, 3);
      expect(xs[0], 0.0);
      expect(xs[1], greaterThan(xs[0]));
      expect(xs[2], greaterThan(xs[1]));
      // All on one row.
      for (var i = 0; i < 3; i++) {
        expect(tester.getTopLeft(find.byKey(ValueKey(i))).dy, 0.0);
      }
    });

    testWidgets('maxColumns caps the count however wide the room',
        (tester) async {
      await _pumpAt(
        tester,
        2000,
        LumaAutoGrid(
          minColumnWidth: 240,
          gap: 12,
          maxColumns: 2,
          children: [
            for (var i = 0; i < 4; i++)
              SizedBox(key: ValueKey(i), height: 40),
          ],
        ),
      );
      // Two per row: the third starts a new one.
      expect(tester.getTopLeft(find.byKey(const ValueKey(1))).dy, 0.0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(2))).dy,
        greaterThan(0.0),
      );
    });
  });

  testWidgets('a row of cells is as tall as its tallest, even with a '
      'LayoutBuilder inside', (tester) async {
    // The regression this exists for: the obvious implementation wraps each
    // row in IntrinsicHeight, and IntrinsicHeight over a LayoutBuilder throws
    //
    //   LayoutBuilder does not support returning intrinsic dimensions.
    //
    // Every cell in this app contains one, because a card that reflows to its
    // own width is the point of the container query. _RenderGridRow lays each
    // row out twice instead of asking it anything.
    await _pumpAt(
      tester,
      620,
      LumaAutoGrid(
        minColumnWidth: 240,
        gap: 12,
        children: [
          LumaContainer(
            child: Container(key: const ValueKey('short'), height: 40),
          ),
          LumaContainer(
            child: Container(key: const ValueKey('tall'), height: 120),
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('short'))).height,
      120,
      reason: 'the short cell should have been stretched to the row height',
    );
  });

  testWidgets('a cell keeps its own height when stretching is off',
      (tester) async {
    await _pumpAt(
      tester,
      620,
      LumaAutoGrid(
        minColumnWidth: 240,
        gap: 12,
        equalRowHeight: false,
        children: [
          Container(key: const ValueKey('short'), height: 40),
          Container(key: const ValueKey('tall'), height: 120),
        ],
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('short'))).height, 40);
  });

  group('LumaContainer measures its own box', () {
    testWidgets('not the window', (tester) async {
      late double measured;
      late LumaWidth size;

      await _pumpAt(
        tester,
        1000,
        // A 300dp column inside a 1000dp window. MediaQuery would say 1000,
        // which is the number the component must not act on.
        SizedBox(
          width: 300,
          child: LumaContainer(
            child: Builder(
              builder: (context) {
                measured = context.lumaContainerWidth;
                size = context.lumaWidth;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(measured, 300);
      expect(size, LumaWidth.compact);
    });

    testWidgets('minus the padding the content will actually sit inside',
        (tester) async {
      late double measured;

      await _pumpAt(
        tester,
        400,
        LumaContainer(
          widthAdjustment: 32,
          child: Builder(
            builder: (context) {
              measured = context.lumaContainerWidth;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(measured, 368);
    });

    testWidgets('the nearest container wins, so a sheet overrides its screen',
        (tester) async {
      late double inner;

      await _pumpAt(
        tester,
        900,
        LumaContainer(
          child: SizedBox(
            width: 320,
            child: LumaContainer(
              child: Builder(
                builder: (context) {
                  inner = context.lumaContainerWidth;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(inner, 320);
    });
  });
}
