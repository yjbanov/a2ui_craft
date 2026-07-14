// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The content-container primitives — `Image`, `Card`, `Divider`,
/// `ScrollView`, `List`.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds an `Image` sized to its [ImageVariant] (so it occupies the same box as
/// the Flutter adapter) with the requested [ImageFit] as `object-fit`.
Component buildImage(BuildContext context, DataSource source) {
  final String? url = source.v<String>(['url']);
  final ImageVariant variant =
      ImageVariant.parse(source.v<String>(['variant']));
  final Map<String, String> raw = <String, String>{
    'width': variant.width != null ? '${px(variant.width!)}px' : '100%',
    'height': '${px(variant.height)}px',
    'object-fit': _objectFit(ImageFit.parse(source.v<String>(['fit']))),
    if (variant.circular) 'border-radius': '50%',
  };
  if (url == null || url.isEmpty) {
    // Placeholder box (keeps tests deterministic and matches Flutter).
    raw['background-color'] = 'rgba(0, 0, 0, 0.12)';
    return div(styles: Styles(raw: raw), const <Component>[]);
  }
  return img(src: url, styles: Styles(raw: raw));
}

/// Builds `Card`: an elevated surface with the stock 16px content padding.
Component buildCard(BuildContext context, DataSource source) {
  final Rgba? surface =
      ambientCraftTheme(context)?.tokens.color(ThemeRoles.surface);
  return div(
    styles: Styles(
      padding: Padding.all(Unit.pixels(16)),
      radius: BorderRadius.circular(Unit.pixels(8)),
      shadow: BoxShadow(
        color: Color.rgba(0, 0, 0, 0.25),
        blur: Unit.pixels(4),
        offsetX: Unit.zero,
        offsetY: Unit.pixels(2),
      ),
      backgroundColor: surface == null
          ? const Color(kSurfaceFallback)
          : Color(surface.toCssString()),
    ),
    [
      source.child(['child'])
    ],
  );
}

/// Builds `Divider`: a hairline rule along `axis`, inked by the `outline` role.
Component buildDivider(BuildContext context, DataSource source) {
  final FlexAxis axis =
      FlexAxis.parse(source.v<String>(['axis']), fallback: FlexAxis.horizontal);
  final String separator =
      roleColor(context, ThemeRoles.outline) ?? kDividerFallback;
  if (axis == FlexAxis.vertical) {
    return div(
      styles: Styles(raw: <String, String>{
        'width': '1px',
        'align-self': 'stretch',
        'background-color': separator,
      }),
      const <Component>[],
    );
  }
  // `align-self: stretch` spans the parent's cross extent without forcing it
  // wider (it contributes ~0 to intrinsic sizing), mirroring Flutter's
  // `Divider`, which fills the column's resolved cross size. A plain <hr>
  // instead inherits `align-items` (e.g. `center`) and collapses to a dot.
  return div(
    styles: Styles(raw: <String, String>{
      'align-self': 'stretch',
      'height': '1px',
      'border': 'none',
      'margin': '0',
      'background-color': separator,
    }),
    const <Component>[],
  );
}

/// Builds `ScrollView`: a scrollable viewport around one child.
///
/// `height: 100%` fills a bounded ancestor so the viewport scrolls within it
/// (mirroring Flutter's `SingleChildScrollView`, which fills its bounded
/// parent); against an auto-height ancestor a percentage height resolves to
/// `auto`, so this is a no-op and the viewport hugs its content as before.
Component buildScrollView(BuildContext context, DataSource source) {
  return div(
    styles: Styles(
      height: 100.percent,
      overflow: Overflow.auto,
    ),
    [
      source.child(['child'])
    ],
  );
}

/// Builds `List`: a scrollable run of children along an axis (A2UI `List`).
Component buildList(BuildContext context, DataSource source) {
  final bool horizontal = FlexAxis.parse(source.v<String>(['direction']),
          fallback: FlexAxis.vertical) ==
      FlexAxis.horizontal;
  final CrossAxisAlign align = CrossAxisAlign.parse(source.v<String>(['align']),
      fallback: CrossAxisAlign.stretch);
  return div(
    styles: Styles(
      display: Display.flex,
      flexDirection: horizontal ? FlexDirection.row : FlexDirection.column,
      alignItems: toAlign(align),
      raw: <String, String>{'overflow': 'auto'},
    ),
    source.childList(['children']),
  );
}

String _objectFit(ImageFit f) => switch (f) {
      ImageFit.contain => 'contain',
      ImageFit.cover => 'cover',
      ImageFit.fill => 'fill',
      ImageFit.none => 'none',
      ImageFit.scaleDown => 'scale-down',
    };
