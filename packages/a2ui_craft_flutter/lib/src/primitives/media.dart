// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The content-container primitives — `Image`, `Card`, `Divider`,
/// `ScrollView`, `List`.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds an `Image` sized to its [ImageVariant] (so it occupies the same box as
/// the Jaspr adapter) with the requested [ImageFit].
///
/// An empty or `example.com` URL renders a sized placeholder instead of a
/// network image, so widget tests stay deterministic and network-free.
Widget buildImage(BuildContext context, DataSource source) {
  final String? url = source.v<String>(['url']);
  final ImageVariant variant =
      ImageVariant.parse(source.v<String>(['variant']));
  final BoxFit fit = _boxFit(ImageFit.parse(source.v<String>(['fit'])));
  final bool placeholder =
      url == null || url.isEmpty || url.contains('example.com');

  final Widget content = placeholder
      ? const ColoredBox(color: Color(0x1F000000))
      : Image.network(url,
          fit: fit, width: variant.width, height: variant.height);

  Widget box =
      SizedBox(width: variant.width, height: variant.height, child: content);
  if (variant.circular) box = ClipOval(child: box);
  return box;
}

/// Builds `Card`: a grouping surface with the specified default decoration
/// (`CardDefaults`) — an outlined surface with a soft shadow.
///
/// The primitive **owns its paint** (a `DecoratedBox`, not Material's `Card`):
/// so its look is our shared spec, identical to the Jaspr render up to idiom,
/// rather than whatever stock chrome the framework supplies (DESIGN.md §8 — the
/// framework must never be visible). The fill inks `color.surface`, the border
/// inks `color.outline`; corner and elevation are specified defaults; every part
/// is overridable by a prop. Material's default 4px `Card` margin is gone with
/// it — spacing between cards is the layout's job (a `Column` `gap`).
Widget buildCard(BuildContext context, DataSource source) {
  final Rgba? colorArg = rgbaArg(source, 'color');
  final Color surface = colorArg != null
      ? Color(colorArg.value)
      : roleColor(context, ThemeRoles.surface) ??
          Theme.of(context).colorScheme.surface;

  final CornerRadius radius = CornerRadius.decode(
      numArg(source, 'cornerRadius'),
      fallback: CardDefaults.cornerRadius);
  final BorderSpec border = BorderSpec.decode(borderRaw(source, 'border'),
      fallback: CardDefaults.border);
  final Elevation elevation = Elevation.decode(numArg(source, 'elevation'),
      fallback: CardDefaults.elevation);
  final Object? padRaw = insetsRaw(source, 'padding');
  final Insets padding =
      padRaw == null ? CardDefaults.padding : Insets.decode(padRaw);

  final Color? borderColor = border.isNone
      ? null
      : border.color != null
          ? Color(border.color!.value)
          : roleColor(context, ThemeRoles.outline) ??
              Theme.of(context).colorScheme.outlineVariant;

  // `DecoratedBox` paints the border straddling the box edge without reserving
  // layout for it, whereas the CSS border-box insets content by the border
  // width. Add the border width to the padding so the child sits the same
  // distance from the edge on both adapters (the geometry conformance pins it).
  final EdgeInsets contentPadding = toEdgeInsets(padding) +
      (border.isNone ? EdgeInsets.zero : EdgeInsets.all(border.width));

  return DecoratedBox(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius.pixels),
      border: borderColor == null
          ? null
          : Border.all(color: borderColor, width: border.width),
      boxShadow: <BoxShadow>[
        for (final ShadowSpec s in elevation.shadows)
          BoxShadow(
            color: Color(s.color.value),
            offset: Offset(0, s.offsetY),
            blurRadius: s.blur,
            spreadRadius: s.spread,
          ),
      ],
    ),
    child: Padding(
      padding: contentPadding,
      child: source.child(['child']),
    ),
  );
}

/// Builds `Divider`: a hairline rule along `axis`, inked by the `outline` role.
Widget buildDivider(BuildContext context, DataSource source) {
  final FlexAxis axis =
      FlexAxis.parse(source.v<String>(['axis']), fallback: FlexAxis.horizontal);
  final Color? color = roleColor(context, ThemeRoles.outline);
  return axis == FlexAxis.vertical
      ? VerticalDivider(color: color)
      : Divider(color: color);
}

/// Builds `ScrollView`: a scrollable viewport around one child.
Widget buildScrollView(BuildContext context, DataSource source) {
  return SingleChildScrollView(
    child: source.child(['child']),
  );
}

/// Builds `List`: a scrollable run of children along an axis (A2UI `List`).
Widget buildList(BuildContext context, DataSource source) {
  final bool horizontal = FlexAxis.parse(source.v<String>(['direction']),
          fallback: FlexAxis.vertical) ==
      FlexAxis.horizontal;
  final CrossAxisAlign align = CrossAxisAlign.parse(source.v<String>(['align']),
      fallback: CrossAxisAlign.stretch);
  return SingleChildScrollView(
    scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
    child: Flex(
      direction: horizontal ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: toCrossAxisAlignment(align),
      children: source.childList(['children']),
    ),
  );
}

BoxFit _boxFit(ImageFit f) => switch (f) {
      ImageFit.contain => BoxFit.contain,
      ImageFit.cover => BoxFit.cover,
      ImageFit.fill => BoxFit.fill,
      ImageFit.none => BoxFit.none,
      ImageFit.scaleDown => BoxFit.scaleDown,
    };
