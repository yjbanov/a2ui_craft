// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Framework-neutral value types for the primitives.
///
/// A small set of types — sizing ([Dimension]), the flex [FlexAxis] and
/// alignments ([MainAxisAlign]/[CrossAxisAlign]), edge [Insets], and [Rgba]
/// color — each with a single canonical representation. Every renderer maps these
/// onto its own native layout, so a template that uses them means the same thing
/// regardless of the framework drawing it.
///
/// Each type exposes a `decode`/`parse` entry point that turns a raw argument
/// value into the type; callers read the raw value from their data source and
/// delegate here.
library;

// Design notes (not part of the public contract):
// - This is the "H2 type model" in DESIGN.md §11: the framework-neutral
//   replacement for RFW's Flutter-specific argument_decoders.
// - Decoding lives here, not in each adapter, so the adapters cannot silently
//   disagree about what "fill" or "spaceBetween" means.
// - Type names deliberately avoid Flutter's (Axis, MainAxisAlignment, …) so an
//   adapter can import this library and package:flutter/material.dart together
//   without prefixing.

/// How a box is sized along one axis: one of [Dimension.hug], [Dimension.fill],
/// [Dimension.fixed], or [Dimension.flex].
///
/// Sizing is always stated explicitly rather than inheriting a framework's
/// default, which is what lets a `Row`/`Column` lay out identically on every
/// renderer:
///
/// * [Dimension.hug] — size to the content (like Flutter `mainAxisSize.min` or
///   CSS `fit-content`).
/// * [Dimension.fill] — fill the available space (Flutter `mainAxisSize.max` /
///   a stretched cross axis; CSS `100%`).
/// * [Dimension.fixed] — an exact pixel size.
/// * [Dimension.flex] — take a share of the parent's free space along its main
///   axis (Flutter `Expanded(flex:)`; CSS `flex-grow`). Only meaningful for a
///   child of a [FlexAxis] container.
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
/// `Row`/`Column` are a `Flex` plus this.
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
/// Maps to Flutter `MainAxisAlignment` / CSS `justify-content`.
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
/// Maps to Flutter `CrossAxisAlignment` / CSS `align-items`.
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
/// The positional constructor takes the sides in CSS shorthand order:
/// `top, right, bottom, left`.
// Named `Insets` (not `EdgeInsets`) so an adapter can import this library and
// package:flutter/material.dart together without prefixing.
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
// Named `Rgba` (not `Color`) so an adapter can import this library alongside
// Flutter's or Jaspr's `Color` without prefixing.
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

/// A hint for a `Text`'s base style.
///
/// The renderer (eventually a theme) decides the concrete size/weight; [body] is
/// the default running text and [caption] is smaller, secondary text.
enum TextVariant {
  body,
  caption;

  /// Parses `"body"` / `"caption"`, defaulting to [body].
  static TextVariant parse(String? raw,
      {TextVariant fallback = TextVariant.body}) {
    switch (raw?.trim()) {
      case 'body':
        return TextVariant.body;
      case 'caption':
        return TextVariant.caption;
      default:
        return fallback;
    }
  }
}

/// How an `Image` is resized to fit its box — the equivalent of CSS
/// `object-fit` and Flutter `BoxFit`.
enum ImageFit {
  contain,
  cover,
  fill,
  none,
  scaleDown;

  /// Parses a canonical name, defaulting to [fallback] ([fill]).
  static ImageFit parse(String? raw, {ImageFit fallback = ImageFit.fill}) {
    switch (raw?.trim()) {
      case 'contain':
        return ImageFit.contain;
      case 'cover':
        return ImageFit.cover;
      case 'fill':
        return ImageFit.fill;
      case 'none':
        return ImageFit.none;
      case 'scaleDown':
        return ImageFit.scaleDown;
      default:
        return fallback;
    }
  }
}

/// A hint for an `Image`'s size and shape.
///
/// Each variant maps to a canonical box ([width] × [height]) that **both
/// adapters share**, so an image of a given variant occupies the same space on
/// Flutter and the web. A null dimension means "fill the available extent on
/// that axis" (the [header] variant spans its container's width).
enum ImageVariant {
  icon,
  avatar,
  smallFeature,
  mediumFeature,
  largeFeature,
  header;

  /// Parses a canonical name, defaulting to [fallback] ([mediumFeature]).
  static ImageVariant parse(String? raw,
      {ImageVariant fallback = ImageVariant.mediumFeature}) {
    switch (raw?.trim()) {
      case 'icon':
        return ImageVariant.icon;
      case 'avatar':
        return ImageVariant.avatar;
      case 'smallFeature':
        return ImageVariant.smallFeature;
      case 'mediumFeature':
        return ImageVariant.mediumFeature;
      case 'largeFeature':
        return ImageVariant.largeFeature;
      case 'header':
        return ImageVariant.header;
      default:
        return fallback;
    }
  }

  /// The canonical width in logical pixels, or null to fill the available width.
  double? get width => switch (this) {
        ImageVariant.icon => 24,
        ImageVariant.avatar => 48,
        ImageVariant.smallFeature => 96,
        ImageVariant.mediumFeature => 160,
        ImageVariant.largeFeature => 280,
        ImageVariant.header => null,
      };

  /// The canonical height in logical pixels.
  double get height => switch (this) {
        ImageVariant.icon => 24,
        ImageVariant.avatar => 48,
        ImageVariant.smallFeature => 96,
        ImageVariant.mediumFeature => 160,
        ImageVariant.largeFeature => 280,
        ImageVariant.header => 200,
      };

  /// Whether the image is clipped to a circle (the [avatar] variant).
  bool get circular => this == ImageVariant.avatar;
}
