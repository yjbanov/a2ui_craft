// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Framework-neutral **specified defaults** for primitives whose look is a
/// default rather than a role (DESIGN.md §8, "the primitives are a
/// specification").
///
/// These live in the core, next to the value types, so both adapters read the
/// *identical* default instead of hardcoding it once per framework — the exact
/// drift §8 warns against ("a padding hard-coded independently on each side").
/// A primitive still lets a prop override any of these, and inks its themeable
/// parts from the semantic contract (§9.4); this file is only the fallbacks.
library;

import 'value_types.dart';

/// `Card`'s specified default decoration: an **outlined surface with a soft
/// shadow**. A Card is layer 1 of the paint model (surface: fill, border, corner)
/// standalone — no state layer, no interaction; its child is content, placed by
/// [padding].
///
/// Themeable parts degrade through the semantic contract (§9.4): the fill inks
/// `color.surface` and the border inks `color.outline` (each falling back to the
/// host default when unthemed). [cornerRadius] and [elevation] are specified
/// defaults, not themeable roles — radius/elevation are deliberately deferred
/// from the v1 contract (§9.4) — but remain per-instance props.
abstract final class CardDefaults {
  /// The content inset. Pinned by the Card geometry conformance together with
  /// the [border] width (the child sits [padding] + border in from the edge, the
  /// border-box model, identically on both adapters).
  static const Insets padding = Insets.all(16);

  /// The corner radius.
  static const CornerRadius cornerRadius = CornerRadius(12);

  /// The default hairline border — `color: null` inks `color.outline`. A border
  /// separates the card reliably in light, dark, and high-contrast, where the
  /// shadow alone is nearly invisible.
  static const BorderSpec border = BorderSpec(width: 1);

  /// The default elevation — a soft shadow that adds depth on light surfaces and
  /// is harmless on dark (where the outline carries the separation).
  static const Elevation elevation = Elevation(2);
}
