// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Responsive` primitive — the ergonomic, template-light way to
/// **restructure** by window size class (research/responsive/RESPONSIVE_DESIGN.md).
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/widgets.dart';

import '../runtime.dart';

/// Builds `Responsive`: renders one of its per-size-class children by the
/// ambient [MediaContext] width class, restructuring the surface without any
/// template-language branching.
///
/// Slots are named by class id — `compact` / `medium` / `expanded` / `large` /
/// `extraLarge` — and any subset may be provided; selection is **mobile-first**
/// (the largest provided class ≤ the current width, else the smallest provided —
/// [WindowSizeClass.resolveResponsive], shared with the Jaspr adapter so both
/// pick the same child). With no ambient media the width defaults to
/// [WindowSizeClass.compact] (mobile-first). Depending on the ambient media
/// scope, a size-class change re-renders this in place (no remount), exactly
/// like a re-theme.
Widget buildResponsive(BuildContext context, DataSource source) {
  final WindowSizeClass width =
      ambientMediaContext(context)?.width ?? WindowSizeClass.compact;
  final Map<WindowSizeClass, Widget> children = <WindowSizeClass, Widget>{};
  for (final WindowSizeClass c in WindowSizeClass.values) {
    final Widget? child = source.optionalChild(<Object>[c.id]);
    if (child != null) children[c] = child;
  }
  final WindowSizeClass? pick =
      WindowSizeClass.resolveResponsive(width, children.keys.toSet());
  return pick == null ? const SizedBox.shrink() : children[pick]!;
}
