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

/// Builds `Card`: an elevated surface with the stock 16px content padding.
Widget buildCard(BuildContext context, DataSource source) {
  return Card(
    // Material's `Card` defaults to `margin: EdgeInsets.all(4)`, which the
    // Jaspr `Card` (a plain div) has no equivalent for — it would add an
    // invisible 4px inset (and ~8px between stacked cards) on Flutter only.
    // Zero it so the primitive is spacing-neutral on both adapters; spacing
    // between cards is the layout's job (a `Column` `gap`).
    margin: EdgeInsets.zero,
    color: roleColor(context, ThemeRoles.surface),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
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
