// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The layout primitives — `Flex`/`Row`/`Column`, `Expanded`, `Center`,
/// `Align`, `AspectRatio`, `Wrap`, `Opacity`, `SizedBox`, `Box` — on the
/// explicit-sizing model shared with the Jaspr adapter (DESIGN.md §8).
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

// Row, Column, and Flex are one builder over a `FlexAxis`: Row/Column pin
// the axis, Flex reads it from `direction` (DESIGN.md §8).

/// Builds `Flex`, reading the axis from `direction`.
Widget buildFlex(BuildContext context, DataSource source) =>
    _flex(source, FlexAxis.parse(source.v<String>(['direction'])));

/// Builds `Row`: a `Flex` pinned horizontal.
Widget buildRow(BuildContext context, DataSource source) =>
    _flex(source, FlexAxis.horizontal);

/// Builds `Column`: a `Flex` pinned vertical.
Widget buildColumn(BuildContext context, DataSource source) =>
    _flex(source, FlexAxis.vertical);

/// Builds `Expanded`: a flex item that grows to take `flex` shares of free
/// space.
Widget buildExpanded(BuildContext context, DataSource source) {
  return Expanded(
    flex: source.v<int>(['flex']) ?? 1,
    child: source.child(['child']),
  );
}

/// Builds `Center`: centers its child within the available space.
Widget buildCenter(BuildContext context, DataSource source) {
  return Center(
    child: source.child(['child']),
  );
}

/// Builds `Align`: places its child at an `alignment` within an (optionally
/// sized) box. With no width/height it hugs the child (alignment is then a
/// no-op); a fixed width/height gives the child room to be positioned.
/// Generalizes `Center`.
Widget buildAlign(BuildContext context, DataSource source) {
  final Alignment2D a = Alignment2D.parse(source.v<String>(['alignment']));
  final double? w = source.v<double>(['width']);
  final double? h = source.v<double>(['height']);
  Widget aligned = Align(
    alignment: Alignment(a.x, a.y),
    // A factor of 1.0 shrink-wraps that axis to the child; null fills the
    // (sized) box so the alignment has free space to position within.
    widthFactor: w == null ? 1.0 : null,
    heightFactor: h == null ? 1.0 : null,
    child: source.child(['child']),
  );
  if (w != null || h != null) {
    aligned = SizedBox(width: w, height: h, child: aligned);
  }
  return aligned;
}

/// Builds `AspectRatio`: sizes its child to a `ratio` (width ÷ height) within
/// the incoming constraints (Flutter `AspectRatio` / CSS `aspect-ratio`).
Widget buildAspectRatio(BuildContext context, DataSource source) {
  return AspectRatio(
    aspectRatio: numArg(source, 'ratio') ?? 1.0,
    child: source.optionalChild(['child']),
  );
}

/// Builds `Wrap`: a run of children that wraps onto the next line/column when
/// they overflow the main axis (Flutter `Wrap` / CSS `flex-wrap`).
Widget buildWrap(BuildContext context, DataSource source) {
  final bool horizontal = FlexAxis.parse(source.v<String>(['direction']),
          fallback: FlexAxis.horizontal) ==
      FlexAxis.horizontal;
  return Wrap(
    direction: horizontal ? Axis.horizontal : Axis.vertical,
    spacing: _gap(source),
    runSpacing: numArg(source, 'runGap') ?? 0.0,
    children: source.childList(['children']),
  );
}

/// Builds `Opacity`: makes its child partially (or fully) transparent without
/// affecting layout.
Widget buildOpacity(BuildContext context, DataSource source) {
  return Opacity(
    opacity: (numArg(source, 'opacity') ?? 1.0).clamp(0.0, 1.0),
    child: source.child(['child']),
  );
}

/// Builds `SizedBox`. The child is optional: a childless SizedBox is a
/// fixed-size spacer.
Widget buildSizedBox(BuildContext context, DataSource source) {
  return SizedBox(
    width: source.v<double>(['width']),
    height: source.v<double>(['height']),
    child: source.optionalChild(['child']),
  );
}

/// Builds a `Box` — the catalog's single container primitive (size + padding +
/// margin + background) — from the spec, on the same explicit-sizing and
/// border-box model the Jaspr adapter renders.
///
/// Composition, inside-out: child → padding → fixed/fill size (child placed
/// top-left, like CSS block flow) → background (fills the padded box, not the
/// margin) → margin. `Container` is deliberately *not* used: with an alignment
/// it expands to fill when unsized, which would break `hug`.
///
/// `margin` is rendered as an outer `Padding`, so the keyed node's measured rect
/// includes the margin — matching how the Jaspr adapter wraps margin. Measuring
/// margin as part of the box (rather than excluding it) is the one consistent
/// contract available, since the runtime lifts the key onto the builder's output.
Widget buildBox(BuildContext context, DataSource source) {
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));
  final Insets padding = Insets.decode(insetsRaw(source, 'padding'));
  final Insets margin = Insets.decode(insetsRaw(source, 'margin'));
  final Rgba? color = rgbaArg(source, 'color');

  Widget box = source.optionalChild(['child']) ?? const SizedBox.shrink();

  if (!padding.isZero) {
    box = Padding(padding: toEdgeInsets(padding), child: box);
  }

  final double? w = _extent(width);
  final double? h = _extent(height);
  if (w != null || h != null) {
    // A definite/fill box places its (smaller) child at the top-left, as a CSS
    // block does — not stretched to fill, which is Flutter's default.
    box = SizedBox(
      width: w,
      height: h,
      child: Align(alignment: Alignment.topLeft, child: box),
    );
  }

  if (color != null) {
    box = ColoredBox(color: Color(color.value), child: box);
  }

  if (!margin.isZero) {
    box = Padding(padding: toEdgeInsets(margin), child: box);
  }

  return box;
}

/// Builds a `Flex` (and thus `Row`/`Column`) from the catalog spec, mapping the
/// framework-neutral value types onto Flutter's `Flex`.
///
/// Sizing is **explicit**: a default `Flex` hugs both axes
/// (`MainAxisSize.min` on the main axis; `CrossAxisAlignment.start`, so children
/// keep their intrinsic cross size and align to the leading edge). `fill`/`fixed`
/// opt into filling or a fixed extent. Neither Flutter's nor CSS's native
/// defaults are inherited, so the same template lays out identically here and in
/// the Jaspr adapter.
Widget _flex(DataSource source, FlexAxis axis) {
  final MainAxisAlign main =
      MainAxisAlign.parse(source.v<String>(['mainAxisAlignment']));
  final CrossAxisAlign cross =
      CrossAxisAlign.parse(source.v<String>(['crossAxisAlignment']));
  final double gap = _gap(source);
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));

  final bool horizontal = axis == FlexAxis.horizontal;
  // The main-axis dimension decides whether the Flex shrink-wraps its children
  // (hug → min) or expands to fill the available/fixed main extent so that
  // `mainAxisAlignment` has free space to distribute.
  final Dimension mainDim = horizontal ? width : height;

  final Widget flex = Flex(
    direction: horizontal ? Axis.horizontal : Axis.vertical,
    mainAxisSize: mainDim is HugDimension ? MainAxisSize.min : MainAxisSize.max,
    mainAxisAlignment: toMainAxisAlignment(main),
    crossAxisAlignment: toCrossAxisAlignment(cross),
    spacing: gap,
    children: source.childList(['children']),
  );

  return _applySizing(flex, width: width, height: height);
}

/// Reads a raw scalar (a number → a fixed size, or a keyword string) for a
/// `Dimension`-valued argument. `DataSource.v` requires a concrete scalar type,
/// so we probe the few a `Dimension` can take.
Object? _dimRaw(DataSource source, List<Object> key) =>
    source.v<double>(key) ?? source.v<int>(key) ?? source.v<String>(key);

/// Reads the `gap` argument, accepting either an int or double literal.
double _gap(DataSource source) =>
    source.v<double>(['gap']) ?? source.v<int>(['gap'])?.toDouble() ?? 0.0;

/// Wraps [child] in a `SizedBox` when either axis is `fixed`/`fill`; `hug`
/// leaves the axis unconstrained (shrink-wrap). `fill` resolves to
/// `double.infinity`, which the bounded parent (a sized container, the test
/// harness, …) gives a concrete extent.
Widget _applySizing(Widget child,
    {required Dimension width, required Dimension height}) {
  final double? w = _extent(width);
  final double? h = _extent(height);
  if (w == null && h == null) return child;
  return SizedBox(width: w, height: h, child: child);
}

double? _extent(Dimension d) => switch (d) {
      FixedDimension(:final double pixels) => pixels,
      FillDimension() => double.infinity,
      HugDimension() => null,
      // A container is not itself a flex child, so `flex(n)` has no meaning here.
      FlexDimension() => null,
    };
