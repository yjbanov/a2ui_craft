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

/// `Grid`'s specified default — the minimum column width for its **auto-fit**
/// track sizing (DESIGN.md §13; research/responsive/RESPONSIVE_DESIGN.md §4.1).
///
/// `Grid` lays out as many equal columns as fit, each at least this wide, then
/// distributes the leftover space evenly across them (CSS
/// `repeat(auto-fit, minmax(min(N, 100%), 1fr))`; the Flutter adapter derives the
/// same column count from the same formula). This is the highest-leverage
/// *intrinsic* responsiveness — a card grid, a photo wall, a dashboard reflows
/// across form factors with **no breakpoints and no size input** — so the width
/// lives here, next to the value types, as the one number both adapters read.
abstract final class GridDefaults {
  /// The default minimum column width (logical px). A per-instance
  /// `minColumnWidth` prop overrides it.
  static const double minColumnWidth = 200;
}

/// `Checkbox`'s specified default geometry — the box's size, corner radius, and
/// border width (DESIGN.md §8, "the paint model"). A checkbox is the four paint
/// layers in miniature: layer 1 is the **box** (border when unchecked, fill when
/// checked, these corners), layer 3 is the **mark**.
///
/// These are *specified defaults, not themeable roles* (radius/size are deferred
/// from the v1 semantic contract, §9.4) and not per-instance props (a checkbox is
/// spec-governed, not styled per use — §8, "no `shape` prop"). They exist here so
/// both adapters read one number instead of hardcoding it twice — the exact drift
/// §8 warns against.
///
/// **Scope:** these govern an *adapter-painted* glyph — the web idiom today, and
/// any adapter that paints its own glyph. An adapter rendering a **native**
/// control (the Flutter `Checkbox.adaptive`) keeps that idiom's own size/corner
/// (legitimate idiom variance, §8) and honors only [borderWidth] (its `side`).
///
/// The themeable parts degrade through the semantic contract (§9.4): the checked
/// fill inks `color.primary`, the mark inks `color.onPrimary`, and the unchecked
/// box inks `color.outline` — each falling back to the host look when unthemed.
abstract final class CheckboxDefaults {
  /// The box's edge length (logical px). Pinned by control conformance.
  static const double size = 18;

  /// The box corner radius — the neutral Craft default for the painted glyph, so
  /// the web corner is a stated value rather than a per-adapter hardcode.
  static const CornerRadius cornerRadius = CornerRadius(4);

  /// The unchecked box border width (logical px). The one geometry knob a native
  /// idiom can still honor (Flutter's `Checkbox.side`).
  static const double borderWidth = 2;
}

/// `Radio`'s specified default geometry. The radio is the same painted-glyph
/// model as the checkbox with one fewer role: layer 1 is the **circle**
/// (`color.outline` ring unselected, `color.primary` ring selected), layer 3 is
/// the **dot** (`color.primary`, selected-only) — there is no `onPrimary` ink, a
/// radio's indicator being the accent itself, not content on an accent fill.
///
/// Like [CheckboxDefaults], these govern the *painted* glyph (the web today, and
/// the Flutter `Icon` glyph's size); a fully native control would keep its own
/// geometry. Specified defaults, not roles or per-instance props (DESIGN.md §8).
abstract final class RadioDefaults {
  /// The glyph's diameter (logical px) — matches [CheckboxDefaults.size] so the
  /// two selection controls read the same size on a form.
  static const double size = 18;

  /// The unselected ring width. Honored by the painted (web) glyph; the Flutter
  /// `Icon` glyph bakes its own ring width (idiom latitude, §8).
  static const double borderWidth = 2;
}

/// `Switch`'s specified default geometry — the track and thumb of the painted
/// glyph. The switch is layer 1 (the **track**: `color.primary` fill active,
/// `color.outline` fill inactive) and layer 3 (the **thumb**: `color.onPrimary`
/// on the active track, a neutral on the inactive one).
///
/// The switch is the one control the web has **no native element** for, so it is
/// *always* adapter-painted (like `Button`, unlike `Checkbox`/`Radio`, which
/// blend into a native control unthemed). The web glyph derives its whole
/// geometry from these: the pill radius is [trackHeight] / 2, and the thumb
/// centers sit [thumbInset] + radius in from each track edge. The native Flutter
/// switch keeps its own geometry (idiom latitude, §8) and reads none of them.
abstract final class SwitchDefaults {
  /// The track's width (logical px).
  static const double trackWidth = 36;

  /// The track's height (logical px); the pill corner radius is half this.
  static const double trackHeight = 20;

  /// The thumb's diameter (logical px).
  static const double thumbDiameter = 14;

  /// The horizontal gap from a track edge to the near thumb edge — the thumb's
  /// travel inset. The thumb centers are [thumbInset] + radius from each edge.
  static const double thumbInset = 4;
}
