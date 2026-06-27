// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Cross-framework value types for the low-level catalog.
///
/// These are the framework-neutral "type model" described in DESIGN.md §11
/// (Pillar B): each type has **one canonical representation** that every adapter
/// maps down to its framework's native layout. They are the replacement for
/// RFW's intensely Flutter-specific `argument_decoders` — the catalog speaks
/// these types, and Flutter/Jaspr each translate them, so a template means the
/// same thing on both.
///
/// Decoding lives here (not in the adapters) on purpose: if each adapter parsed
/// raw argument values itself, the two could silently disagree about what
/// `"fill"` or `"spaceBetween"` means. Adapters read the raw scalar out of their
/// `DataSource` and hand it to these `decode`/`parse` entry points; only the
/// final *mapping* to a framework primitive is adapter-specific.
///
/// The names here deliberately avoid Flutter's (`Axis`, `MainAxisAlignment`, …)
/// so an adapter can import both this library and `package:flutter/material.dart`
/// without prefixing.
library;

/// How a box is sized along one axis (DESIGN.md §11: the explicit-sizing
/// decision that removes default-divergence between Flutter and CSS).
///
/// The canonical forms are `hug` | `fill` | `fixed(px)` | `flex(n)`:
///
/// * [hug] — size to the content (Flutter `mainAxisSize.min`; CSS `fit-content`).
/// * [fill] — fill the available space (Flutter `mainAxisSize.max` / a stretched
///   cross axis; CSS `100%`).
/// * [fixed] — an exact pixel size.
/// * [flex] — take a share of the parent's free space along its main axis
///   (Flutter `Expanded(flex:)`; CSS `flex-grow`). Only meaningful for a child of
///   a [FlexAxis] container.
///
/// Neither platform's defaults are inherited; sizing is always stated, which is
/// what keeps a `Row`/`Column` laying out identically on both sides.
sealed class Dimension {
  const Dimension();

  /// Size to content.
  const factory Dimension.hug() = HugDimension;

  /// Fill the available space.
  const factory Dimension.fill() = FillDimension;

  /// An exact size in logical pixels.
  const factory Dimension.fixed(double pixels) = FixedDimension;

  /// Take [factor] shares of the parent's free main-axis space.
  const factory Dimension.flex([int factor]) = FlexDimension;

  /// Decodes a raw argument value (as read from a `DataSource`) into a
  /// [Dimension].
  ///
  /// Accepts a bare number (→ [Dimension.fixed]) or one of the keyword strings
  /// understood by [parseKeyword] (`"hug"`, `"fill"`, `"flex"`, `"flex(n)"`).
  /// Anything unrecognized or absent yields [fallback] (default [Dimension.hug]).
  static Dimension decode(Object? raw,
      {Dimension fallback = const HugDimension()}) {
    if (raw is num) return FixedDimension(raw.toDouble());
    if (raw is String) return parseKeyword(raw) ?? fallback;
    return fallback;
  }

  /// Parses a keyword form: `"hug"`, `"fill"`, `"flex"`, `"flex(2)"`, or a bare
  /// numeric string like `"100"` (→ fixed). Returns null if unrecognized.
  static Dimension? parseKeyword(String raw) {
    final String s = raw.trim().toLowerCase();
    switch (s) {
      case 'hug':
        return const HugDimension();
      case 'fill':
        return const FillDimension();
      case 'flex':
        return const FlexDimension();
    }
    if (s.startsWith('flex(') && s.endsWith(')')) {
      final int? n = int.tryParse(s.substring(5, s.length - 1).trim());
      if (n != null && n > 0) return FlexDimension(n);
    }
    final double? px = double.tryParse(s);
    if (px != null) return FixedDimension(px);
    return null;
  }
}

/// Size to content. See [Dimension.hug].
final class HugDimension extends Dimension {
  const HugDimension();
  @override
  bool operator ==(Object other) => other is HugDimension;
  @override
  int get hashCode => (HugDimension).hashCode;
  @override
  String toString() => 'hug';
}

/// Fill available space. See [Dimension.fill].
final class FillDimension extends Dimension {
  const FillDimension();
  @override
  bool operator ==(Object other) => other is FillDimension;
  @override
  int get hashCode => (FillDimension).hashCode;
  @override
  String toString() => 'fill';
}

/// An exact pixel size. See [Dimension.fixed].
final class FixedDimension extends Dimension {
  const FixedDimension(this.pixels);

  /// The size in logical pixels.
  final double pixels;

  @override
  bool operator ==(Object other) =>
      other is FixedDimension && other.pixels == pixels;
  @override
  int get hashCode => Object.hash(FixedDimension, pixels);
  @override
  String toString() => 'fixed($pixels)';
}

/// A share of the parent's free main-axis space. See [Dimension.flex].
final class FlexDimension extends Dimension {
  const FlexDimension([this.factor = 1]);

  /// The number of shares to take (must be positive).
  final int factor;

  @override
  bool operator ==(Object other) =>
      other is FlexDimension && other.factor == factor;
  @override
  int get hashCode => Object.hash(FlexDimension, factor);
  @override
  String toString() => 'flex($factor)';
}

/// The axis a [Flex] lays its children along.
///
/// `Row`/`Column` in the catalog are a `Flex` plus this (DESIGN.md §11).
enum FlexAxis {
  /// Children are laid out left-to-right (a `Row`).
  horizontal,

  /// Children are laid out top-to-bottom (a `Column`).
  vertical;

  /// Parses `"horizontal"` / `"vertical"`, defaulting to [fallback].
  static FlexAxis parse(String? raw, {FlexAxis fallback = FlexAxis.vertical}) {
    switch (raw?.trim().toLowerCase()) {
      case 'horizontal':
        return FlexAxis.horizontal;
      case 'vertical':
        return FlexAxis.vertical;
      default:
        return fallback;
    }
  }
}

/// Placement of children along a [Flex]'s main axis.
///
/// Maps to Flutter `MainAxisAlignment` / CSS `justify-content` (DESIGN.md §11).
enum MainAxisAlign {
  start,
  center,
  end,
  spaceBetween,
  spaceAround,
  spaceEvenly;

  /// Parses a canonical name, defaulting to [fallback] ([start]).
  static MainAxisAlign parse(String? raw,
      {MainAxisAlign fallback = MainAxisAlign.start}) {
    switch (raw?.trim()) {
      case 'start':
        return MainAxisAlign.start;
      case 'center':
        return MainAxisAlign.center;
      case 'end':
        return MainAxisAlign.end;
      case 'spaceBetween':
        return MainAxisAlign.spaceBetween;
      case 'spaceAround':
        return MainAxisAlign.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlign.spaceEvenly;
      default:
        return fallback;
    }
  }
}

/// Placement of children along a [Flex]'s cross axis.
///
/// Maps to Flutter `CrossAxisAlignment` / CSS `align-items` (DESIGN.md §11).
enum CrossAxisAlign {
  start,
  center,
  end,
  stretch;

  /// Parses a canonical name, defaulting to [fallback] ([center]).
  static CrossAxisAlign parse(String? raw,
      {CrossAxisAlign fallback = CrossAxisAlign.center}) {
    switch (raw?.trim()) {
      case 'start':
        return CrossAxisAlign.start;
      case 'center':
        return CrossAxisAlign.center;
      case 'end':
        return CrossAxisAlign.end;
      case 'stretch':
        return CrossAxisAlign.stretch;
      default:
        return fallback;
    }
  }
}

/// An immutable set of offsets in each of the four cardinal directions, used for
/// padding and margin.
///
/// The name avoids Flutter's `EdgeInsets` (and the field order follows the CSS
/// shorthand `top right bottom left`), so an adapter can import this library and
/// `package:flutter/material.dart` together without prefixing.
final class Insets {
  const Insets(this.top, this.right, this.bottom, this.left);

  /// The same offset on all four sides.
  const Insets.all(double value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  /// Symmetric [vertical] (top/bottom) and [horizontal] (left/right) offsets.
  const Insets.symmetric({double vertical = 0, double horizontal = 0})
      : top = vertical,
        bottom = vertical,
        left = horizontal,
        right = horizontal;

  /// Offsets given in Flutter's left/top/right/bottom order (a convenience for
  /// adapters that map down to a Flutter `EdgeInsets.fromLTRB`).
  const Insets.fromLTRB(this.left, this.top, this.right, this.bottom);

  /// No offset on any side.
  static const Insets zero = Insets(0, 0, 0, 0);

  final double top;
  final double right;
  final double bottom;
  final double left;

  /// Whether every side is zero.
  bool get isZero => top == 0 && right == 0 && bottom == 0 && left == 0;

  /// Decodes a raw argument value into [Insets].
  ///
  /// Accepts:
  /// - `num`: the same offset on all sides.
  /// - `[vertical, horizontal]`: a 2-element array.
  /// - `[top, right, bottom, left]`: a 4-element array in CSS order.
  ///
  /// Anything else (wrong length, non-numeric elements, absent) yields [zero].
  /// This is the single source of truth for inset decoding; adapters extract the
  /// raw value from their `DataSource` and delegate here.
  static Insets decode(Object? raw) {
    if (raw is num) return Insets.all(raw.toDouble());
    if (raw is List) {
      if (raw.length == 2) {
        final double? v = _asDouble(raw[0]);
        final double? h = _asDouble(raw[1]);
        if (v != null && h != null) {
          return Insets.symmetric(vertical: v, horizontal: h);
        }
      } else if (raw.length == 4) {
        final double? t = _asDouble(raw[0]);
        final double? r = _asDouble(raw[1]);
        final double? b = _asDouble(raw[2]);
        final double? l = _asDouble(raw[3]);
        if (t != null && r != null && b != null && l != null) {
          return Insets(t, r, b, l);
        }
      }
    }
    return zero;
  }

  static double? _asDouble(Object? o) => o is num ? o.toDouble() : null;

  @override
  bool operator ==(Object other) =>
      other is Insets &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  @override
  String toString() => 'Insets($top, $right, $bottom, $left)';
}

/// A color stored as a 32-bit ARGB integer (`0xAARRGGBB`).
///
/// The name avoids Flutter's and Jaspr's `Color`, so an adapter can import this
/// library alongside either without prefixing.
final class Rgba {
  const Rgba(this.value);

  /// The packed `0xAARRGGBB` value.
  final int value;

  /// Decodes a CSS-style hex string into an [Rgba].
  ///
  /// Accepts `"#RRGGBB"` (assumed opaque) or `"#AARRGGBB"`, case-insensitive.
  /// Returns null for anything else (no `#`, wrong length, non-hex, non-string).
  static Rgba? decode(Object? raw) {
    if (raw is! String) return null;
    String s = raw.trim();
    if (!s.startsWith('#')) return null;
    s = s.substring(1);
    if (s.length == 6) s = 'FF$s'; // Default to opaque.
    if (s.length != 8) return null;
    final int? val = int.tryParse(s, radix: 16);
    return val == null ? null : Rgba(val);
  }

  /// The alpha channel, 0–255.
  int get alpha => (value >> 24) & 0xFF;

  /// The red channel, 0–255.
  int get red => (value >> 16) & 0xFF;

  /// The green channel, 0–255.
  int get green => (value >> 8) & 0xFF;

  /// The blue channel, 0–255.
  int get blue => value & 0xFF;

  /// Returns a CSS-compatible `rgba(...)` string (alpha as a 0–1 fraction).
  String toCssString() => 'rgba($red, $green, $blue, ${alpha / 255.0})';

  @override
  bool operator ==(Object other) => other is Rgba && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      'Rgba(0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}
