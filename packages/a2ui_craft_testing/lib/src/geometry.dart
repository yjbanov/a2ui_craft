// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

/// A layout rectangle in the surface's pixel space, as measured from a rendered
/// node (Flutter `RenderBox` geometry; Jaspr `getBoundingClientRect`).
///
/// Coordinates are absolute within the test surface; the conformance cases
/// compare children *relative to their container*, so the surface's own origin
/// (Material padding, browser body margin, …) cancels out.
class CraftRect {
  const CraftRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  @override
  String toString() =>
      'CraftRect(left: $left, top: $top, width: $width, height: $height)';
}

/// A framework-neutral handle to a *mounted* surface that can be **measured**.
///
/// This is the geometry counterpart to `CraftTester` (DESIGN.md §11, Pillar C):
/// where `CraftTester`'s probes are behavioral ("is this text visible?"), these
/// answer "where, and how big, is this node?" — within a tolerance band, never
/// pixel-exact (§5). Each adapter implements it over its real renderer: Flutter
/// via `WidgetTester` geometry, Jaspr via a headless-browser `getBoundingClientRect`.
abstract interface class CraftGeometryTester {
  /// Parses [template] as the `main` library (with `core` available) and renders
  /// its `root`, then settles layout.
  Future<void> mountTemplate(String template, {DynamicContent? data});

  /// The absolute layout rect of the node carrying the component `key`.
  Future<CraftRect> rectOf(String key);
}

/// Registers geometry conformance cases with a framework's browser/widget test
/// runner. The adapter constructs a [CraftGeometryTester] per case.
abstract interface class CraftGeometryDriver {
  void defineTest(
    String description,
    Future<void> Function(CraftGeometryTester tester) body,
  );
}

/// How close two measured coordinates must be to count as equal. Parity is
/// behavioral within a tolerance band, not pixel-exact (DESIGN.md §5, §11
/// Pillar C); the fixtures use fixed-size boxes (no text shaping) so the real
/// divergence is sub-pixel rounding.
const double _tol = 1.0;

/// The shared **geometric** specification for the `Flex` slice of the catalog.
///
/// Every adapter runs this against its own renderer; passing it proves that
/// `Flex` (and `Row`/`Column`/`Expanded`) lays out identically — sizing,
/// main/cross alignment, gap, and flex distribution — not merely that children
/// are present. Fixtures use fixed-size `SizedBox` children so the assertions
/// are independent of font metrics.
void runFlexGeometryConformance(CraftGeometryDriver driver) {
  driver.defineTest(
    'Row main-axis start lays children left-to-right, spaced by gap',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Row(
          key: "box", width: 200.0, height: 40.0,
          mainAxisAlignment: "start", gap: 10.0,
          children: [
            SizedBox(key: "a", width: 40.0, height: 20.0),
            SizedBox(key: "b", width: 40.0, height: 20.0),
            SizedBox(key: "c", width: 40.0, height: 20.0),
          ],
        );
      ''');
      final CraftRect box = await tester.rectOf('box');
      expect((await tester.rectOf('a')).left - box.left, closeTo(0, _tol));
      expect((await tester.rectOf('b')).left - box.left, closeTo(50, _tol));
      expect((await tester.rectOf('c')).left - box.left, closeTo(100, _tol));
      expect((await tester.rectOf('a')).width, closeTo(40, _tol));
    },
  );

  driver.defineTest(
    'Row main-axis center centers the content block in free space',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Row(
          key: "box", width: 200.0, height: 40.0,
          mainAxisAlignment: "center",
          children: [
            SizedBox(key: "a", width: 40.0, height: 20.0),
            SizedBox(key: "b", width: 40.0, height: 20.0),
          ],
        );
      ''');
      // content = 80 of 200 ⇒ 120 free ⇒ first child starts at 60.
      final CraftRect box = await tester.rectOf('box');
      expect((await tester.rectOf('a')).left - box.left, closeTo(60, _tol));
      expect((await tester.rectOf('b')).left - box.left, closeTo(100, _tol));
    },
  );

  driver.defineTest(
    'Row main-axis spaceBetween pushes the children to the edges',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Row(
          key: "box", width: 200.0, height: 40.0,
          mainAxisAlignment: "spaceBetween",
          children: [
            SizedBox(key: "a", width: 40.0, height: 20.0),
            SizedBox(key: "b", width: 40.0, height: 20.0),
          ],
        );
      ''');
      final CraftRect box = await tester.rectOf('box');
      expect((await tester.rectOf('a')).left - box.left, closeTo(0, _tol));
      expect((await tester.rectOf('b')).left - box.left, closeTo(160, _tol));
    },
  );

  driver.defineTest(
    'Row cross-axis alignment positions children start / center / end',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Column(children: [
          Row(key: "s", width: 120.0, height: 100.0,
              crossAxisAlignment: "start",
              children: [ SizedBox(key: "cs", width: 20.0, height: 20.0) ]),
          Row(key: "c", width: 120.0, height: 100.0,
              crossAxisAlignment: "center",
              children: [ SizedBox(key: "cc", width: 20.0, height: 20.0) ]),
          Row(key: "e", width: 120.0, height: 100.0,
              crossAxisAlignment: "end",
              children: [ SizedBox(key: "ce", width: 20.0, height: 20.0) ]),
        ]);
      ''');
      // 20-tall child in a 100-tall row: top edge, centered (40), bottom (80).
      expect((await tester.rectOf('cs')).top - (await tester.rectOf('s')).top,
          closeTo(0, _tol));
      expect((await tester.rectOf('cc')).top - (await tester.rectOf('c')).top,
          closeTo(40, _tol));
      expect((await tester.rectOf('ce')).top - (await tester.rectOf('e')).top,
          closeTo(80, _tol));
    },
  );

  driver.defineTest(
    'Expanded children divide the main axis by their flex factor',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Row(
          key: "box", width: 200.0, height: 20.0,
          children: [
            Expanded(key: "one", flex: 1, child: SizedBox(height: 20.0)),
            Expanded(key: "three", flex: 3, child: SizedBox(height: 20.0)),
          ],
        );
      ''');
      // 1:3 split of 200 ⇒ 50 and 150, the second starting at 50.
      final CraftRect box = await tester.rectOf('box');
      expect((await tester.rectOf('one')).width, closeTo(50, _tol));
      expect((await tester.rectOf('three')).width, closeTo(150, _tol));
      expect((await tester.rectOf('three')).left - box.left, closeTo(50, _tol));
    },
  );

  driver.defineTest(
    'Column main-axis start lays children top-to-bottom, spaced by gap',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Column(
          key: "box", width: 40.0, height: 200.0,
          mainAxisAlignment: "start", gap: 10.0,
          children: [
            SizedBox(key: "a", width: 20.0, height: 20.0),
            SizedBox(key: "b", width: 20.0, height: 20.0),
            SizedBox(key: "c", width: 20.0, height: 20.0),
          ],
        );
      ''');
      final CraftRect box = await tester.rectOf('box');
      expect((await tester.rectOf('a')).top - box.top, closeTo(0, _tol));
      expect((await tester.rectOf('b')).top - box.top, closeTo(30, _tol));
      expect((await tester.rectOf('c')).top - box.top, closeTo(60, _tol));
    },
  );
}
