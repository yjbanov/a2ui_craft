// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The layout primitives — `Flex`/`Row`/`Column`, `Expanded`, `Center`,
/// `Align`, `AspectRatio`, `Wrap`, `Opacity`, `SizedBox`, `Box` — on the
/// explicit-sizing model shared with the Flutter adapter (DESIGN.md §8).
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

// Row, Column, and Flex are one builder over a `FlexAxis`: Row/Column pin
// the axis, Flex reads it from `direction` (DESIGN.md §8).

/// Builds `Flex`, reading the axis from `direction`.
Component buildFlex(BuildContext context, DataSource source) =>
    _flex(source, FlexAxis.parse(source.v<String>(['direction'])));

/// Builds `Row`: a `Flex` pinned horizontal.
Component buildRow(BuildContext context, DataSource source) =>
    _flex(source, FlexAxis.horizontal);

/// Builds `Column`: a `Flex` pinned vertical.
Component buildColumn(BuildContext context, DataSource source) =>
    _flex(source, FlexAxis.vertical);

/// Builds `Expanded`: a flex item that grows to take `flex` shares of free
/// space, like Flutter's `Expanded(flex:)`: grow factor, shrink 1, basis 0.
Component buildExpanded(BuildContext context, DataSource source) {
  final int flex = source.v<int>(['flex']) ?? 1;
  return div(
    styles: Styles(raw: <String, String>{'flex': '$flex 1 0'}),
    <Component>[
      source.child(['child'])
    ],
  );
}

/// Builds `Center`: centers its child within the available space.
///
/// Flutter's `Center` (an `Align` with null size factors) expands to the
/// largest size the incoming constraints allow, then centers its child —
/// shrink-wrapping only when a constraint is unbounded. A bare flex box
/// collapses to its content instead, pinning the child top-left, so fill
/// the parent explicitly: `100%` fills a bounded parent (where centering
/// has room) and resolves to the child's size in an unbounded one — the
/// same caveat Flutter documents.
Component buildCenter(BuildContext context, DataSource source) {
  return div(
    styles: Styles(
      display: Display.flex,
      justifyContent: JustifyContent.center,
      alignItems: AlignItems.center,
      width: Unit.percent(100),
      height: Unit.percent(100),
    ),
    [
      source.child(['child'])
    ],
  );
}

/// Builds `Align`: places its child at an `alignment` within an (optionally
/// sized) box. With no width/height it hugs the child (alignment is then a
/// no-op); a fixed width/height gives the child room to be positioned.
/// Generalizes `Center`.
Component buildAlign(BuildContext context, DataSource source) {
  final Alignment2D a = Alignment2D.parse(source.v<String>(['alignment']));
  final double? w = source.v<double>(['width']);
  final double? h = source.v<double>(['height']);
  return div(
    styles: Styles(
      display: Display.flex,
      justifyContent: _justifyFor(a.x),
      alignItems: _alignItemsFor(a.y),
      width: w != null ? Unit.pixels(w) : null,
      height: h != null ? Unit.pixels(h) : null,
    ),
    [
      source.child(['child'])
    ],
  );
}

/// Builds `AspectRatio`: sizes its child to a `ratio` (width ÷ height) within
/// the incoming constraints (CSS `aspect-ratio` / Flutter `AspectRatio`).
Component buildAspectRatio(BuildContext context, DataSource source) {
  final double ratio = numArg(source, 'ratio') ?? 1.0;
  final Component? child = source.optionalChild(['child']);
  return div(
    styles: Styles(raw: <String, String>{
      'aspect-ratio': '$ratio',
      'width': '100%',
    }),
    _childList(child),
  );
}

/// Builds `Wrap`: a run of children that wraps onto the next line/column when
/// they overflow the main axis (CSS `flex-wrap` / Flutter `Wrap`).
Component buildWrap(BuildContext context, DataSource source) {
  final bool horizontal = FlexAxis.parse(source.v<String>(['direction']),
          fallback: FlexAxis.horizontal) ==
      FlexAxis.horizontal;
  final double spacing = _gap(source);
  final double runSpacing = numArg(source, 'runGap') ?? 0.0;
  // CSS `gap` shorthand is `row-gap column-gap`. For a horizontal wrap the
  // run axis is vertical (row-gap = runSpacing) and item spacing is
  // horizontal (column-gap = spacing); for a vertical wrap it is the reverse.
  final String gap = horizontal
      ? '${runSpacing}px ${spacing}px'
      : '${spacing}px ${runSpacing}px';
  return div(
    styles: Styles(raw: <String, String>{
      'display': 'flex',
      'flex-direction': horizontal ? 'row' : 'column',
      'flex-wrap': 'wrap',
      'gap': gap,
    }),
    source.childList(['children']),
  );
}

/// Builds `Opacity`: makes its child partially (or fully) transparent without
/// affecting layout.
Component buildOpacity(BuildContext context, DataSource source) {
  final double o = (numArg(source, 'opacity') ?? 1.0).clamp(0.0, 1.0);
  return div(
    styles: Styles(raw: <String, String>{'opacity': '$o'}),
    [
      source.child(['child'])
    ],
  );
}

/// Builds `SizedBox`. The child is optional: a childless SizedBox is a
/// fixed-size spacer.
Component buildSizedBox(BuildContext context, DataSource source) {
  final double? w = source.v<double>(['width']);
  final double? h = source.v<double>(['height']);
  final Component? child = source.optionalChild(['child']);
  return div(
    styles: Styles(
      width: w != null ? Unit.pixels(w) : null,
      height: h != null ? Unit.pixels(h) : null,
    ),
    _childList(child),
  );
}

/// Builds a `Box` — the catalog's single container primitive (size + padding +
/// margin + background) — from the spec, on the same explicit-sizing and
/// border-box model the Flutter adapter renders.
///
/// `margin` is rendered as an **outer wrapper** rather than CSS `margin`, so the
/// keyed node's `getBoundingClientRect` *includes* the margin band — matching the
/// Flutter adapter (whose margin `Padding` is likewise part of the measured box).
/// The wrapper sizes to fill only when the box itself fills; otherwise it hugs
/// the inner box plus its margin. This keeps the measured footprint identical
/// across adapters (CSS `margin` would otherwise be excluded from the rect).
Component buildBox(BuildContext context, DataSource source) {
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));
  final Insets padding = Insets.decode(insetsRaw(source, 'padding'));
  final Insets margin = Insets.decode(insetsRaw(source, 'margin'));
  final Rgba? color = _rgba(source, 'color');
  final Component? child = source.optionalChild(['child']);

  final Map<String, String> inner = <String, String>{
    'box-sizing': 'border-box',
    'width': _cssExtent(width),
    'height': _cssExtent(height),
  };
  if (!padding.isZero) inner['padding'] = cssInsets(padding);
  if (color != null) inner['background-color'] = color.toCssString();

  Component box = div(styles: Styles(raw: inner), _childList(child));

  if (!margin.isZero) {
    box = div(
      styles: Styles(raw: <String, String>{
        'box-sizing': 'border-box',
        // The wrapper fills only if the box fills; otherwise it hugs inner+margin.
        'width': width is FillDimension ? '100%' : 'fit-content',
        'height': height is FillDimension ? '100%' : 'fit-content',
        'padding': cssInsets(margin),
      }),
      <Component>[box],
    );
  }

  return box;
}

/// Builds a `Flex` (and thus `Row`/`Column`) from the catalog spec, mapping the
/// framework-neutral value types onto a CSS flex container.
///
/// Sizing is **explicit**: a default `Flex` hugs both axes
/// (`width`/`height: fit-content`; `align-items: flex-start`, so children keep
/// their intrinsic cross size and align to the leading edge). This deliberately
/// does *not* inherit CSS's native block-level defaults (a `display:flex` div
/// would fill its inline axis and stretch its children), so the same template
/// lays out identically here and in the Flutter adapter. `fill`/`fixed` opt into
/// `100%`/an exact pixel extent.
Component _flex(DataSource source, FlexAxis axis) {
  final MainAxisAlign main =
      MainAxisAlign.parse(source.v<String>(['mainAxisAlignment']));
  final CrossAxisAlign cross =
      CrossAxisAlign.parse(source.v<String>(['crossAxisAlignment']));
  final double gap = _gap(source);
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));
  final bool horizontal = axis == FlexAxis.horizontal;

  // The main axis hugs to content (`fit-content`). The cross axis, when it hugs,
  // is left to CSS `auto` rather than `fit-content`: as a block-level flex this
  // fills the parent's cross size (so a fixed-width ancestor like `Box(width:)`
  // reaches a `fill` descendant, and a full-bleed `Divider` spans the card),
  // while a flex *item* (e.g. a `Stat` column inside a `Row`) still shrink-wraps.
  // This mirrors how Flutter's constraints carry a bounded cross extent down to
  // its children, which a rigid `fit-content` would sever.
  final Dimension mainDim = horizontal ? width : height;
  final Dimension crossDim = horizontal ? height : width;
  final String mainExtent = _cssExtent(mainDim);
  final String? crossExtent =
      crossDim is HugDimension ? null : _cssExtent(crossDim);
  final String widthCss = horizontal ? mainExtent : (crossExtent ?? 'auto');
  final String heightCss = horizontal ? (crossExtent ?? 'auto') : mainExtent;

  return div(
    styles: Styles(
      display: Display.flex,
      flexDirection: horizontal ? FlexDirection.row : FlexDirection.column,
      justifyContent: toJustify(main),
      alignItems: toAlign(cross),
      raw: <String, String>{
        'width': widthCss,
        'height': heightCss,
        if (gap > 0) 'gap': '${px(gap)}px',
      },
    ),
    source.childList(['children']),
  );
}

/// Reads a raw scalar for a `Dimension`-valued argument.
Object? _dimRaw(DataSource source, List<Object> key) =>
    source.v<double>(key) ?? source.v<int>(key) ?? source.v<String>(key);

/// Reads the `gap` argument, accepting either an int or double literal.
double _gap(DataSource source) =>
    source.v<double>(['gap']) ?? source.v<int>(['gap'])?.toDouble() ?? 0.0;

Rgba? _rgba(DataSource source, String key) =>
    Rgba.decode(source.v<String>([key]));

String _cssExtent(Dimension d) => switch (d) {
      HugDimension() => 'fit-content',
      FillDimension() => '100%',
      FixedDimension(:final double pixels) => '${px(pixels)}px',
      // A container is not itself a flex child, so `flex(n)` has no meaning here.
      FlexDimension() => 'fit-content',
    };

List<Component> _childList(Component? child) => switch (child) {
      final Component c => <Component>[c],
      _ => const <Component>[],
    };

/// Maps an `Alignment2D` horizontal anchor (`x` in `[-1, 1]`) to the
/// main-axis `justify-content` of the (row) flex box that positions the child.
JustifyContent _justifyFor(double x) => x < 0
    ? JustifyContent.start
    : x > 0
        ? JustifyContent.end
        : JustifyContent.center;

/// Maps an `Alignment2D` vertical anchor (`y` in `[-1, 1]`) to the cross-axis
/// `align-items` of the (row) flex box that positions the child.
AlignItems _alignItemsFor(double y) => y < 0
    ? AlignItems.start
    : y > 0
        ? AlignItems.end
        : AlignItems.center;
