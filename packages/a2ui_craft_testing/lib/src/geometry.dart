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
/// This is the geometry counterpart to `CraftTester` (DESIGN.md §8, Pillar C):
/// where `CraftTester`'s probes are behavioral ("is this text visible?"), these
/// answer "where, and how big, is this node?" — within a tolerance band, never
/// pixel-exact (§7). Each adapter implements it over its real renderer: Flutter
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
/// behavioral within a tolerance band, not pixel-exact (DESIGN.md §7, §8
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

  driver.defineTest(
    'adjacent Text children are independent flex items, separated by the gap',
    (CraftGeometryTester tester) async {
      // Each `Text` must be its own flex item. On the web a bare text node is
      // not an element, so the flexbox spec merges a run of adjacent text
      // nodes into ONE anonymous flex item — collapsing sibling Texts so the
      // Column's gap never lands between them. The Jaspr adapter therefore
      // wraps every Text in a span; this pins that (and matches Flutter, where
      // a Text widget is always its own child).
      await tester.mountTemplate('''
        import core;
        widget root = Column(key: "box", gap: 16.0, crossAxisAlignment: "start",
          children: [
            Text(key: "a", text: "Alpha"),
            Text(key: "b", text: "Beta"),
          ]);
      ''');
      final CraftRect a = await tester.rectOf('a');
      final CraftRect b = await tester.rectOf('b');
      // Beta sits strictly below Alpha (two items, not one merged text run)…
      expect(b.top, greaterThan(a.top + 1));
      // …separated by exactly the gap. Font-independent: the gap is inserted
      // between the flex items, whatever the line height.
      expect(b.top - a.bottom, closeTo(16, _tol));
    },
  );
}

/// The shared **geometric** specification for **cross-axis hug sizing** — how a
/// `Flex` that hugs its cross axis resolves its extent when a bounded ancestor
/// and a cross-filling child are in play.
///
/// This guards the parity decision that a hug cross axis defers to the parent's
/// constraints (Flutter carries a bounded cross extent down; the Jaspr adapter
/// uses CSS `auto`, not `fit-content`) rather than collapsing to content. Both
/// fixtures pass on Flutter and *failed* on the prior Jaspr `fit-content` model,
/// so a regression of either — the cross-axis sizing or the stretch `Divider` —
/// turns this red. These were the Stats Card / Contact Card divergences.
void runCrossAxisSizingGeometryConformance(CraftGeometryDriver driver) {
  driver.defineTest(
    'a fill child reaches a fixed-width ancestor through a hug column',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "box", width: 200.0, height: 100.0,
          child: Column(key: "col", children: [
            Row(key: "fill", width: "fill", height: 20.0, children: [
              SizedBox(key: "a", width: 10.0, height: 20.0),
            ]),
          ])
        );
      ''');
      // The column hugs (no explicit cross extent), but the fixed 200-wide Box
      // must reach the `fill` Row through it: the column resolves to 200 and the
      // Row fills it — it does not collapse to the 10-wide content.
      expect((await tester.rectOf('col')).width, closeTo(200, _tol));
      expect((await tester.rectOf('fill')).width, closeTo(200, _tol));
    },
  );

  driver.defineTest(
    'a Divider spans a hug column and center uses the resolved width',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "box", width: 120.0,
          child: Column(key: "col", crossAxisAlignment: "center", children: [
            SizedBox(key: "wide", width: 40.0, height: 20.0),
            Divider(key: "div"),
            SizedBox(key: "narrow", width: 20.0, height: 20.0),
          ])
        );
      ''');
      // The column fills the 120-wide Box; the Divider spans that full width
      // (it does not collapse), and the 20-wide child centers within 120 (offset
      // (120-20)/2 = 50) — not within a content-collapsed width.
      final CraftRect col = await tester.rectOf('col');
      expect(col.width, closeTo(120, _tol));
      expect((await tester.rectOf('div')).width, closeTo(120, _tol));
      expect(
          (await tester.rectOf('narrow')).left - col.left, closeTo(50, _tol));
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

  driver.defineTest(
    'Box: a border insets content by padding + border, identically per adapter',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "outer", width: 100.0, height: 100.0,
          padding: 10.0, border: 4.0,
          child: Box(key: "inner", width: "fill", height: "fill"));
      ''');
      // border-box: the 100x100 footprint is unchanged by the border; the fill
      // child sits padding (10) + border (4) = 14 in on every side. The CSS
      // border-box does this natively; the Flutter adapter folds the border
      // width into its padding so a `DecoratedBox` (which doesn't reserve
      // border layout) agrees.
      final CraftRect outer = await tester.rectOf('outer');
      final CraftRect inner = await tester.rectOf('inner');
      expect(outer.width, closeTo(100, _tol));
      expect(inner.left - outer.left, closeTo(14, _tol));
      expect(inner.top - outer.top, closeTo(14, _tol));
      expect(inner.width, closeTo(100 - 28, _tol));
      expect(inner.height, closeTo(100 - 28, _tol));
    },
  );

  driver.defineTest(
    'Box: maxWidth caps a fill width identically on both adapters',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "outer", width: 300.0, height: 40.0,
          child: Box(key: "capped", width: "fill", maxWidth: 120.0, height: 20.0));
      ''');
      // The child would fill the 300-wide parent, but `maxWidth` caps it at 120
      // (CSS `max-width` vs. Flutter's outer `ConstrainedBox`).
      expect((await tester.rectOf('capped')).width, closeTo(120, _tol));
    },
  );

  driver.defineTest(
    'Box: minWidth floors a narrow width identically on both adapters',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "outer", width: 300.0, height: 40.0,
          child: Box(key: "floored", width: 40.0, minWidth: 100.0, height: 20.0));
      ''');
      // The child asks for 40 but `minWidth` floors it at 100.
      expect((await tester.rectOf('floored')).width, closeTo(100, _tol));
    },
  );

  driver.defineTest(
    'a Heading adds no margin: it sits at the padding offset on both adapters',
    (CraftGeometryTester tester) async {
      // A Heading is a bare sized text line — no intrinsic margin (like the
      // Flutter `Text`). On the web the browser's default h1–h6 margin would
      // otherwise push it ~0.83em down and inflate any tight container (the
      // calculator-display regression). Pinned via the offset (font-independent:
      // driven by the padding, not the line height).
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "box", padding: 10.0,
          child: Heading(key: "h", text: "Hi", level: 2));
      ''');
      final CraftRect box = await tester.rectOf('box');
      final CraftRect heading = await tester.rectOf('h');
      expect(heading.top - box.top, closeTo(10, _tol));
      expect(heading.left - box.left, closeTo(10, _tol));
    },
  );
}

/// The shared **geometric** specification for the atoms slice — `Image` variant
/// sizing and `List` direction. (Text/Icon are not geometry-tested: text shaping
/// is the documented cross-engine divergence, §7.)
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
    'Center fills a bounded parent and centers its child',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "box", width: 100.0, height: 100.0,
          child: Center(child: SizedBox(key: "c", width: 20.0, height: 20.0))
        );
      ''');
      final CraftRect box = await tester.rectOf('box');
      final CraftRect c = await tester.rectOf('c');
      // The Center expands to fill the bounded 100×100 box (it does not collapse
      // to the 20×20 child), so the child is centered at offset (40, 40).
      expect(c.left - box.left, closeTo(40, _tol));
      expect(c.top - box.top, closeTo(40, _tol));
    },
  );

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

/// The shared **geometric** specification for the `Card` container.
///
/// Pins that `Card` is **spacing-neutral and identical across adapters**: its
/// only inset is the specified default decoration — the 16px content padding
/// plus the 1px default hairline border (`CardDefaults`) — with no
/// framework-default margin. The child therefore sits 17px in on both adapters:
/// the CSS border-box insets content by the border, and the Flutter adapter
/// (whose `DecoratedBox` border does not reserve layout) adds the border width
/// to its padding to match. Since the Card now owns its paint (no Material
/// `Card`), Material's default 4px margin is gone by construction; a regression
/// that reintroduced a margin, or that let the border-inset diverge, turns this
/// red.
void runCardGeometryConformance(CraftGeometryDriver driver) {
  driver.defineTest(
    'Card content inset is padding + border only, identical across adapters',
    (CraftGeometryTester tester) async {
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "box", width: 100.0, height: 100.0,
          child: Card(key: "card",
            child: Box(key: "inner", width: 20.0, height: 20.0)));
      ''');
      final CraftRect box = await tester.rectOf('box');
      final CraftRect inner = await tester.rectOf('inner');
      // 16px padding + 1px default border, no framework margin.
      expect(inner.left - box.left, closeTo(17, _tol));
      expect(inner.top - box.top, closeTo(17, _tol));
    },
  );
}

/// The shared **geometric** specification for the `Grid` primitive — auto-fit
/// track sizing (research/responsive/RESPONSIVE_DESIGN.md §4.1).
///
/// Pins the parity contract that matters: both adapters place the **same number
/// of equal columns at the same width** for a given container, and wrap to the
/// next row at the same point — the Flutter adapter deriving the column count
/// from the same `⌊(W + gap) / (min + gap)⌋` formula CSS `auto-fit minmax()`
/// uses, not merely rendering *a* grid. Fixtures use fixed-height, track-filling
/// cells so the assertions are independent of text shaping.
void runGridGeometryConformance(CraftGeometryDriver driver) {
  driver.defineTest(
    'Grid auto-fit: equal columns, shared track width, wraps to the next row',
    (CraftGeometryTester tester) async {
      // W=300, min=90, gap=10 ⇒ n = ⌊(300+10)/(90+10)⌋ = 3 columns.
      // track = (300 − 2·10)/3 = 93.33; column pitch = track + gap = 103.33.
      // Five cells ⇒ row 0 = a,b,c; row 1 = d,e at runGap (10) below the
      // 20-tall first row (top 30), packed from the start in the same tracks.
      // The Grid sits inside a hug `Column` (whose cross-axis default is
      // `start`) under a fixed-width `Box` — the everyday placement. The Grid
      // must *fill* that 300 width through the start-aligned column, not shrink
      // to one min-width column; a bare block parent would hide that.
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "box", width: 300.0, child: Column(children: [
          Grid(minColumnWidth: 90.0, gap: 10.0, runGap: 10.0, children: [
            SizedBox(key: "a", height: 20.0),
            SizedBox(key: "b", height: 20.0),
            SizedBox(key: "c", height: 20.0),
            SizedBox(key: "d", height: 20.0),
            SizedBox(key: "e", height: 20.0),
          ]),
        ]));
      ''');
      final CraftRect a = await tester.rectOf('a');
      final CraftRect b = await tester.rectOf('b');
      final CraftRect c = await tester.rectOf('c');
      final CraftRect d = await tester.rectOf('d');
      final CraftRect e = await tester.rectOf('e');
      // Three equal tracks on the first row, each ~93.33 wide, pitched 103.33.
      expect(a.width, closeTo(93.33, _tol));
      expect((a.top - a.top), closeTo(0, _tol));
      expect(b.left - a.left, closeTo(103.33, _tol));
      expect((b.top - a.top).abs(), closeTo(0, _tol));
      expect(c.left - a.left, closeTo(206.67, _tol));
      // The fourth cell wraps to the next row (runGap below), back in track 0…
      expect(d.top - a.top, closeTo(30, _tol));
      expect((d.left - a.left).abs(), closeTo(0, _tol));
      // …and the fifth sits in track 1 at the same pitch and width.
      expect(e.left - a.left, closeTo(103.33, _tol));
      expect(e.width, closeTo(93.33, _tol));
    },
  );

  driver.defineTest(
    'Grid auto-fit: few items collapse empty tracks and stretch to fill',
    (CraftGeometryTester tester) async {
      // W=300, min=90 ⇒ up to 3 tracks fit, but only two items: the empty
      // trailing track collapses so the two share the full width (each
      // (300−10)/2 = 145), rather than sitting in 93-wide tracks.
      await tester.mountTemplate('''
        import core;
        widget root = Box(key: "box", width: 300.0, child: Column(children: [
          Grid(minColumnWidth: 90.0, gap: 10.0, children: [
            SizedBox(key: "a", height: 20.0),
            SizedBox(key: "b", height: 20.0),
          ]),
        ]));
      ''');
      final CraftRect a = await tester.rectOf('a');
      final CraftRect b = await tester.rectOf('b');
      expect(a.width, closeTo(145, _tol));
      expect(b.left - a.left, closeTo(155, _tol));
      expect((b.top - a.top).abs(), closeTo(0, _tol));
    },
  );
}
