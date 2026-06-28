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

/// The shared **geometric** specification for the `Box` primitive (size +
/// padding + margin on the constrained common model).
///
/// The insets are deliberately **asymmetric** (`[top, right, bottom, left]` all
/// distinct), so a per-side ordering bug — in decode, in the Flutter
/// `EdgeInsets.fromLTRB` remap, or in the CSS shorthand — is caught rather than
/// hidden by equal values. Fixtures use fixed-size boxes; no text.
void runBoxGeometryConformance(CraftGeometryDriver driver) {
  driver.defineTest(
    'Box: border-box sizing — asymmetric padding shrinks a fill child per side',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(
          key: "outer", width: 100.0, height: 100.0,
          padding: [10.0, 20.0, 30.0, 40.0],
          child: Box(key: "inner", width: "fill", height: "fill")
        );
      ''');
      // padding is t=10, r=20, b=30, l=40 (CSS order). With border-box, the
      // 100x100 box has a content area of 100-(l40+r20)=40 wide, 100-(t10+b30)=60
      // tall, at offset (left 40, top 10). A fill child exactly covers it — so
      // each of the four sides is checked independently:
      //   left offset → l, top offset → t, width → l+r, height → t+b.
      final CraftRect outer = await tester.rectOf('outer');
      final CraftRect inner = await tester.rectOf('inner');
      expect(outer.width, closeTo(100, _tol));
      expect(outer.height, closeTo(100, _tol));
      expect(inner.left - outer.left, closeTo(40, _tol));
      expect(inner.top - outer.top, closeTo(10, _tol));
      expect(inner.width, closeTo(40, _tol));
      expect(inner.height, closeTo(60, _tol));
    },
  );

  driver.defineTest(
    'Box: asymmetric margin offsets content and is part of the measured box',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "outer", width: 200.0, height: 200.0,
          child: Box(key: "mid", margin: [10.0, 20.0, 30.0, 40.0],
            child: Box(key: "leaf", width: 50.0, height: 50.0)
          )
        );
      ''');
      // margin is t=10, r=20, b=30, l=40; the middle box hugs its 50x50 leaf.
      final CraftRect outer = await tester.rectOf('outer');
      final CraftRect mid = await tester.rectOf('mid');
      final CraftRect leaf = await tester.rectOf('leaf');

      // The leaf is pushed in by the *left*/*top* margin (40, 10).
      expect(leaf.left - outer.left, closeTo(40, _tol));
      expect(leaf.top - outer.top, closeTo(10, _tol));

      // The middle box's measured footprint *includes* the margin band on every
      // side — identically on both adapters — so it starts at the outer's origin
      // and is leaf + (l+r) wide, leaf + (t+b) tall. (left+right margin = 60,
      // top+bottom = 40.)
      expect(mid.left - outer.left, closeTo(0, _tol));
      expect(mid.top - outer.top, closeTo(0, _tol));
      expect(mid.width, closeTo(110, _tol));
      expect(mid.height, closeTo(90, _tol));
    },
  );
}

/// The shared **geometric** specification for the atoms slice — `Image` variant
/// sizing and `List` direction. (Text/Icon are not geometry-tested: text shaping
/// is the documented cross-engine divergence, §5.)
void runAtomGeometryConformance(CraftGeometryDriver driver) {
  driver.defineTest(
    'Image variant occupies its canonical box (same on both adapters)',
    (CraftGeometryTester tester) async {
      // Empty URLs render a sized placeholder, so the box is deterministic.
      await tester.mountTemplate('''
        import core;
        widget root = Column(children: [
          Image(key: "avatar", url: "", variant: "avatar"),
          Image(key: "icon", url: "", variant: "icon"),
        ]);
      ''');
      final CraftRect avatar = await tester.rectOf('avatar');
      expect(avatar.width, closeTo(48, _tol));
      expect(avatar.height, closeTo(48, _tol));
      final CraftRect icon = await tester.rectOf('icon');
      expect(icon.width, closeTo(24, _tol));
      expect(icon.height, closeTo(24, _tol));
    },
  );

  driver.defineTest(
    'List lays its children along its direction',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = List(key: "list", direction: "horizontal", children: [
          SizedBox(key: "a", width: 20.0, height: 20.0),
          SizedBox(key: "b", width: 20.0, height: 20.0),
        ]);
      ''');
      final CraftRect a = await tester.rectOf('a');
      final CraftRect b = await tester.rectOf('b');
      // Horizontal: the second child sits one item-width to the right, level top.
      expect(b.left - a.left, closeTo(20, _tol));
      expect((b.top - a.top).abs(), closeTo(0, _tol));
    },
  );
}

/// The shared **geometric** specification for the layout-depth primitives —
/// `Align`, `AspectRatio`, and `Wrap` — beyond the Flex/Box slices. Each is
/// driven by fixed-size fixtures so the assertions are independent of text
/// shaping, and each runs identically on both adapters.
void runLayoutGeometryConformance(CraftGeometryDriver driver) {
  driver.defineTest(
    'Align positions its child at the alignment within a sized box',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Align(
          key: "box", alignment: "bottomRight", width: 100.0, height: 60.0,
          child: SizedBox(key: "c", width: 20.0, height: 20.0),
        );
      ''');
      final CraftRect box = await tester.rectOf('box');
      final CraftRect c = await tester.rectOf('c');
      expect(box.width, closeTo(100, _tol));
      expect(box.height, closeTo(60, _tol));
      // bottomRight: child's right edge at the box's right (100-20=80) and its
      // bottom at the box's bottom (60-20=40).
      expect(c.left - box.left, closeTo(80, _tol));
      expect(c.top - box.top, closeTo(40, _tol));
    },
  );

  driver.defineTest(
    'AspectRatio derives height from a width-bounded constraint',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = SizedBox(key: "box", width: 100.0,
          child: AspectRatio(key: "ar", ratio: 2.0,
            child: SizedBox()
          )
        );
      ''');
      final CraftRect ar = await tester.rectOf('ar');
      // width 100, ratio 2 ⇒ height 50, on both adapters.
      expect(ar.width, closeTo(100, _tol));
      expect(ar.height, closeTo(50, _tol));
    },
  );

  driver.defineTest(
    'Wrap flows children and wraps to the next run on overflow',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = SizedBox(key: "box", width: 100.0,
          child: Wrap(children: [
            SizedBox(key: "a", width: 40.0, height: 20.0),
            SizedBox(key: "b", width: 40.0, height: 20.0),
            SizedBox(key: "c", width: 40.0, height: 20.0),
          ])
        );
      ''');
      final CraftRect a = await tester.rectOf('a');
      final CraftRect b = await tester.rectOf('b');
      final CraftRect c = await tester.rectOf('c');
      // Two 40-wide items fit in 100; `a` and `b` share the first run...
      expect((b.top - a.top).abs(), closeTo(0, _tol));
      expect(b.left - a.left, closeTo(40, _tol));
      // ...and the third wraps to the next run, back at the start.
      expect(c.top - a.top, closeTo(20, _tol));
      expect((c.left - a.left).abs(), closeTo(0, _tol));
    },
  );
}
