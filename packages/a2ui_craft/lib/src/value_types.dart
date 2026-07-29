// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Framework-neutral value types for the primitives.
///
/// A small set of types — sizing ([Dimension]), the flex [FlexAxis] and
/// alignments ([MainAxisAlign]/[CrossAxisAlign]), edge [Insets], [Rgba]
/// color, corner rounding ([CornerRadius]), container decoration
/// ([BorderSpec], [Elevation]), motion ([Motion], [MotionEasing]), and
/// typefaces ([FontRole], [CraftFonts]) — each with a single canonical
/// representation.
/// Every renderer maps these onto its own native layout, so a template that uses
/// them means the same thing regardless of the framework drawing it.
///
/// Each type exposes a `decode`/`parse` entry point that turns a raw argument
/// value into the type; callers read the raw value from their data source and
/// delegate here.
library;

// Design notes (not part of the public contract):
// - This is the "H2 type model" in DESIGN.md §8: the framework-neutral
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

  /// Parses a canonical name, defaulting to [fallback] ([start]).
  ///
  /// The default is [start] — children keep their intrinsic cross size and align
  /// to the leading edge, the natural layout for most content (and what the genui
  /// reference renderer also defaults to). It is deliberately neither Flutter's
  /// native default ([center]) nor CSS's ([stretch]); a container that wants
  /// either states it explicitly.
  static CrossAxisAlign parse(String? raw,
      {CrossAxisAlign fallback = CrossAxisAlign.start}) {
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

/// A point within a box, used to place a child inside it (the `Align`
/// primitive).
///
/// Each value is one of the nine canonical positions (the three horizontal ×
/// three vertical anchors). It maps to Flutter's `Alignment` via [x]/[y] (both
/// in `[-1, 1]`) and to CSS `justify-content`/`align-items` on the web, so an
/// aligned child lands in the same spot on every renderer.
enum Alignment2D {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  /// Parses a canonical camelCase name (e.g. `"topLeft"`, `"center"`,
  /// `"bottomRight"`), defaulting to [fallback] ([center]).
  static Alignment2D parse(String? raw,
      {Alignment2D fallback = Alignment2D.center}) {
    switch (raw?.trim()) {
      case 'topLeft':
        return Alignment2D.topLeft;
      case 'topCenter':
        return Alignment2D.topCenter;
      case 'topRight':
        return Alignment2D.topRight;
      case 'centerLeft':
        return Alignment2D.centerLeft;
      case 'center':
        return Alignment2D.center;
      case 'centerRight':
        return Alignment2D.centerRight;
      case 'bottomLeft':
        return Alignment2D.bottomLeft;
      case 'bottomCenter':
        return Alignment2D.bottomCenter;
      case 'bottomRight':
        return Alignment2D.bottomRight;
      default:
        return fallback;
    }
  }

  /// The horizontal anchor as a fraction in `[-1, 1]`: `-1` left, `0` center,
  /// `1` right (Flutter `Alignment.x`).
  double get x => switch (this) {
        Alignment2D.topLeft ||
        Alignment2D.centerLeft ||
        Alignment2D.bottomLeft =>
          -1,
        Alignment2D.topCenter ||
        Alignment2D.center ||
        Alignment2D.bottomCenter =>
          0,
        Alignment2D.topRight ||
        Alignment2D.centerRight ||
        Alignment2D.bottomRight =>
          1,
      };

  /// The vertical anchor as a fraction in `[-1, 1]`: `-1` top, `0` center,
  /// `1` bottom (Flutter `Alignment.y`).
  double get y => switch (this) {
        Alignment2D.topLeft ||
        Alignment2D.topCenter ||
        Alignment2D.topRight =>
          -1,
        Alignment2D.centerLeft ||
        Alignment2D.center ||
        Alignment2D.centerRight =>
          0,
        Alignment2D.bottomLeft ||
        Alignment2D.bottomCenter ||
        Alignment2D.bottomRight =>
          1,
      };
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

/// The rounding of a box's corners: a single radius in logical pixels.
///
/// The amount of rounding is the author's input; how the corner *curves* — a
/// circular arc, or a platform's continuous curve — is the rendering idiom's
/// decision (DESIGN.md §8, "Corner radius is an amount; corner style is
/// idiom"). `0` is sharp; a value larger than half the box's smaller extent
/// reads as "as round as possible" (pill / circle): both engines reduce
/// overlapping corner curves proportionally — Skia's `RRect` radius scaling
/// and CSS's overlapping-curves rule are the same algorithm — so adapters pass
/// the value through and the clamp agrees natively.
final class CornerRadius {
  const CornerRadius(this.pixels);

  /// Sharp corners — no rounding.
  static const CornerRadius none = CornerRadius(0);

  /// The corner radius in logical pixels (never negative).
  final double pixels;

  /// Whether the corners are sharp (no rounding to draw).
  bool get isSharp => pixels <= 0;

  /// Decodes a raw argument value into a [CornerRadius].
  ///
  /// Accepts a non-negative finite number. Anything else (negative, NaN,
  /// non-numeric, absent) yields [fallback] (default [none]) — a per-corner
  /// form is a reserved future extension, not silently misread.
  static CornerRadius decode(Object? raw,
      {CornerRadius fallback = CornerRadius.none}) {
    if (raw is num && raw.isFinite && raw >= 0) {
      return CornerRadius(raw.toDouble());
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is CornerRadius && other.pixels == pixels;

  @override
  int get hashCode => Object.hash(CornerRadius, pixels);

  @override
  String toString() => 'CornerRadius($pixels)';
}

/// A box's border: a uniform stroke of [width] logical pixels, optionally in an
/// explicit [color].
///
/// A [color] of `null` means the stroke is inked by the primitive's mapped role
/// (a `Card`'s border takes `color.outline`), degrading to the host default when
/// unthemed — the same rule as every other role (DESIGN.md §9.4). A [width] of
/// `0` is [none]. Border *style* (the dashed / double / groove forms CSS offers)
/// is deliberately not modeled: a solid hairline is the one form both frameworks
/// render identically, and anything richer is the replacement escape hatch.
// Named `BorderSpec` (not `Border`) because both Flutter and Jaspr export a
// `Border` class — the same non-collision rule as `Rgba`/`Insets`/`CornerRadius`.
final class BorderSpec {
  const BorderSpec({required this.width, this.color});

  /// No border.
  static const BorderSpec none = BorderSpec(width: 0);

  /// The stroke width in logical pixels (never negative).
  final double width;

  /// The explicit stroke color, or null to ink the mapped role / host default.
  final Rgba? color;

  /// Whether there is no stroke to draw.
  bool get isNone => width <= 0;

  /// Decodes a raw argument value into a [BorderSpec].
  ///
  /// Accepts:
  /// - `num`: a role-inked stroke of that width (`<= 0` → [none]).
  /// - `{ "width": n, "color": "#RRGGBB"? }`: an explicit width and color.
  /// - `false`: [none] (an explicit "no border", to override a default);
  ///   `true`: [fallback] (keep the default).
  ///
  /// Anything else (absent, malformed) yields [fallback].
  static BorderSpec decode(Object? raw, {BorderSpec fallback = none}) {
    if (raw is bool) return raw ? fallback : none;
    if (raw is num) {
      return raw > 0 ? BorderSpec(width: raw.toDouble()) : none;
    }
    if (raw is Map) {
      final Object? w = raw['width'];
      if (w is num) {
        return w > 0
            ? BorderSpec(width: w.toDouble(), color: Rgba.decode(raw['color']))
            : none;
      }
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is BorderSpec && other.width == width && other.color == color;

  @override
  int get hashCode => Object.hash(BorderSpec, width, color);

  @override
  String toString() => 'BorderSpec(width: $width, color: $color)';
}

/// One drop-shadow layer in the framework-neutral vocabulary, produced by
/// [shadowForElevation] and painted by the adapters (Flutter `BoxShadow`, CSS
/// `box-shadow`).
///
/// Defining the shadow ourselves — rather than leaning on Material's stock
/// elevation on one side and a hand-tuned `box-shadow` on the other — is what
/// keeps the depth cue from diverging by *framework* (DESIGN.md §8).
// `ShadowSpec` (not `Shadow`) — Flutter exports `Shadow`/`BoxShadow`.
final class ShadowSpec {
  const ShadowSpec({
    required this.offsetY,
    required this.blur,
    required this.spread,
    required this.color,
  });

  /// Vertical offset in logical pixels (shadows fall straight down; no x-offset).
  final double offsetY;

  /// Gaussian blur radius in logical pixels.
  final double blur;

  /// How much the shadow expands (+) or contracts (−) before blurring.
  final double spread;

  /// The shadow color (typically translucent black).
  final Rgba color;

  @override
  bool operator ==(Object other) =>
      other is ShadowSpec &&
      other.offsetY == offsetY &&
      other.blur == blur &&
      other.spread == spread &&
      other.color == color;

  @override
  int get hashCode => Object.hash(offsetY, blur, spread, color);

  @override
  String toString() =>
      'ShadowSpec(offsetY: $offsetY, blur: $blur, spread: $spread, $color)';
}

/// A box's elevation: a non-negative depth in logical pixels ("dp"), mapped to a
/// canonical shadow by [shadowForElevation].
///
/// The *amount* of depth is the author's input and shared across adapters; how
/// the engine rasterizes the blur is idiom, exactly like corner *style* is idiom
/// while corner *amount* ([CornerRadius]) is shared (DESIGN.md §8). `0` is flat.
final class Elevation {
  const Elevation(this.dp);

  /// Flat — casts no shadow.
  static const Elevation none = Elevation(0);

  /// The depth in logical pixels (never negative).
  final double dp;

  /// Whether there is no shadow to cast.
  bool get isFlat => dp <= 0;

  /// The canonical shadow layers for this depth (empty when flat).
  List<ShadowSpec> get shadows => shadowForElevation(dp);

  /// Decodes a raw argument value into an [Elevation].
  ///
  /// Accepts a non-negative finite number; anything else yields [fallback].
  static Elevation decode(Object? raw, {Elevation fallback = none}) {
    if (raw is num && raw.isFinite && raw >= 0) {
      return Elevation(raw.toDouble());
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) => other is Elevation && other.dp == dp;

  @override
  int get hashCode => Object.hash(Elevation, dp);

  @override
  String toString() => 'Elevation($dp)';
}

/// The canonical shadow for an elevation of [dp] logical pixels: a single soft
/// ambient shadow that scales with depth — vertical offset `dp`, blur `2·dp`, no
/// spread, at 20% black. `dp <= 0` casts nothing.
///
/// Shared by both adapters so the raised look matches within tolerance (the
/// amount is specified; the raster is idiom — DESIGN.md §8). A richer multi-layer
/// elevation ramp is a compatible future refinement of this one function.
List<ShadowSpec> shadowForElevation(double dp) {
  if (dp <= 0) return const <ShadowSpec>[];
  return <ShadowSpec>[
    ShadowSpec(
      offsetY: dp,
      blur: dp * 2,
      spread: 0,
      color: const Rgba(0x33000000), // rgba(0, 0, 0, 0.2)
    ),
  ];
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

  /// Returns the `#AARRGGBB` hex form — the canonical color encoding in
  /// template value positions, round-trippable through [decode].
  String toHexString() =>
      '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

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

/// The quantized **easing vocabulary** for motion — the interpolation curve a
/// transition follows over its duration.
///
/// Each value carries its canonical **cubic-bézier control points**
/// `(x1, y1, x2, y2)`. Those points are the single source both adapters read
/// (Flutter `Cubic(x1, y1, x2, y2)` ↔ CSS `cubic-bezier(x1, y1, x2, y2)`), so
/// the curve is *genuinely identical* across frameworks — only the frame cadence
/// differs, which is the platform latitude DESIGN.md §7 already permits. Motion
/// is a token system parallel to color/type: authors name an intent, not raw
/// beziers (a bespoke curve is the future escape hatch).
///
/// Named `MotionEasing` (not `Easing`) because Flutter's Material library exports
/// an `Easing` class — the same non-collision rule as `BorderSpec`/`Rgba`, and
/// kept out of downstream template-author code either way (motion is set in the
/// template, not by naming this type in Dart).
// The point sets follow Material 3's standard easing set. `emphasized` is a
// single-cubic *approximation* — M3's true emphasized curve is a two-segment
// path no single cubic-bézier expresses; exact parity is a later refinement, and
// it does not affect cross-adapter identity (both adapters read these same
// points).
enum MotionEasing {
  /// Constant velocity — no acceleration. For continuous, mechanical motion.
  linear('linear', 0, 0, 1, 1),

  /// The default: a gentle accelerate-in, decelerate-out for elements that both
  /// begin and end at rest (M3 standard).
  standard('standard', 0.2, 0, 0, 1),

  /// A more expressive standard, for motion that should draw the eye
  /// (approximation of M3 emphasized).
  emphasized('emphasized', 0.05, 0.7, 0.1, 1),

  /// Enters quickly then eases to rest — for elements appearing on screen
  /// (M3 standard decelerate).
  decelerate('decelerate', 0, 0, 0, 1),

  /// Starts at rest then speeds up — for elements leaving the screen
  /// (M3 standard accelerate).
  accelerate('accelerate', 0.3, 0, 1, 1);

  const MotionEasing(this.id, this.x1, this.y1, this.x2, this.y2);

  /// The token string a theme/template uses to name this easing.
  final String id;

  /// The cubic-bézier control points — the first control point (`x1`, `y1`) and
  /// the second (`x2`, `y2`); the curve runs from `(0, 0)` to `(1, 1)`.
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  /// Decodes a raw argument value into a [MotionEasing].
  ///
  /// Accepts the canonical [id] string (whitespace-trimmed); anything else
  /// (absent, unknown, non-string) yields [fallback] (default [standard]).
  /// Total, like every value-type decoder.
  static MotionEasing decode(Object? raw,
      {MotionEasing fallback = MotionEasing.standard}) {
    if (raw is String) {
      final String id = raw.trim();
      for (final MotionEasing e in values) {
        if (e.id == id) return e;
      }
    }
    return fallback;
  }
}

/// A **motion**: how a property change animates — a non-negative [durationMs]
/// and an interpolation [easing]. `0` (or [none]) is instant (no animation).
///
/// This is the carrier the `Box(animate:)` modifier consumes. There is
/// deliberately no standalone `Duration` value type: Dart core's `Duration`
/// would collide the way `Border`/`BorderSpec` did, and a duration is never used
/// here without an easing — so the two travel together.
final class Motion {
  const Motion({required this.durationMs, this.easing = MotionEasing.standard});

  /// Instant — no animation (the property snaps to its new value).
  static const Motion none = Motion(durationMs: 0);

  /// The transition length in milliseconds (treated as `0` — instant — when not
  /// positive).
  final int durationMs;

  /// The interpolation curve followed over [durationMs].
  final MotionEasing easing;

  /// Whether this describes no animation (a non-positive duration).
  bool get isInstant => durationMs <= 0;

  /// Decodes a raw argument value into a [Motion].
  ///
  /// Accepts:
  /// - `true`: [fallback] (animate with the caller's default — e.g. `Box`
  ///   passes the theme's default motion); `false`: [none] (explicitly off).
  /// - `num` (finite, `>= 0`): that many milliseconds with the [standard]
  ///   easing.
  /// - `{ "duration": ms, "easing": "standard"? }`: an explicit duration and
  ///   easing (a `theme.motion.*` reference resolves to one of these forms
  ///   before decode).
  ///
  /// Anything else (absent, malformed, negative, non-finite) yields [fallback].
  /// Total: a bad value never becomes a silent non-zero animation.
  static Motion decode(Object? raw, {Motion fallback = none}) {
    if (raw is bool) return raw ? fallback : none;
    if (raw is num) {
      return raw.isFinite && raw >= 0
          ? Motion(durationMs: raw.round(), easing: MotionEasing.standard)
          : fallback;
    }
    if (raw is Map) {
      final Object? d = raw['duration'];
      if (d is num && d.isFinite && d >= 0) {
        return Motion(
          durationMs: d.round(),
          easing: MotionEasing.decode(raw['easing']),
        );
      }
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      other is Motion &&
      other.durationMs == durationMs &&
      other.easing == easing;

  @override
  int get hashCode => Object.hash(Motion, durationMs, easing);

  @override
  String toString() => 'Motion(durationMs: $durationMs, easing: ${easing.id})';
}

/// A **font role**: the closed vocabulary of typefaces a template or theme may
/// name — a *request to the host*, never a specific font file.
///
/// Fonts are host-provided, in the same sense primitives and functions are. A
/// surface asks for "the monospace face"; the host decides which typeface that
/// is and where its bytes come from ([CraftFonts]). The vocabulary is closed
/// for the same reason the easing set is: a quantized, intent-named vocabulary
/// is the guard rail. It also keeps surfaces honest about weight — an arbitrary
/// family name is a download the host never agreed to, and a look the host's
/// design system never sanctioned.
///
/// A closed set is additionally the only thing that *can* work everywhere.
/// Flutter's CanvasKit web renderer resolves families solely from fonts
/// registered with its font collection — it has no notion of the CSS generic
/// families, so an unregistered name silently renders as the fallback rather
/// than as a system serif. Three roles the host can always answer beats an open
/// namespace that degrades invisibly on the platform that matters most.
enum FontRole {
  /// The UI face — the default for body, caption, and heading text. By host
  /// convention this is the platform's own UI font, so surfaces feel native to
  /// where they run.
  sans('sans'),

  /// A serif face, for editorial or long-form emphasis.
  serif('serif'),

  /// A fixed-pitch face: code spans, tabular figures, anything column-aligned.
  mono('mono');

  const FontRole(this.id);

  /// The token string a theme/template uses to name this role.
  final String id;

  /// Decodes a raw argument value into a [FontRole].
  ///
  /// Accepts the canonical [id] string (whitespace-trimmed); anything else
  /// (absent, unknown, non-string) yields [fallback]. Total, like every
  /// value-type decoder.
  static FontRole decode(Object? raw, {FontRole fallback = FontRole.sans}) =>
      tryDecode(raw) ?? fallback;

  /// The [FontRole] [raw] names, or null if it names none.
  ///
  /// The nullable sibling of [decode], for the one caller that must tell
  /// "this theme asked for [sans]" apart from "this theme said nothing" —
  /// `resolveFontFamily`, where silence means *leave the host's own font
  /// alone* rather than *impose a default*.
  static FontRole? tryDecode(Object? raw) {
    if (raw is! String) return null;
    final String id = raw.trim();
    for (final FontRole role in values) {
      if (role.id == id) return role;
    }
    return null;
  }
}

/// The **host's font binding**: which concrete typefaces answer each
/// [FontRole], as an ordered family stack per role (most specific first, a
/// last-resort generic last).
///
/// This is the seam the user of an adapter owns. A host that ships its own
/// typefaces — or that must, because its target cannot borrow the platform's —
/// hands the adapter a different [CraftFonts] and every surface re-faces at
/// once. The default ([systemUi]) borrows the platform UI font and asks for
/// nothing, which is why it is safe as a default but *only* a default: on
/// Flutter web today the generic entries resolve only to whatever the embedder
/// registered, so a host targeting that platform is expected to supply real
/// families here.
///
/// Deliberately not decodable from template data: the binding is a host
/// decision, and a surface that could name its own font files would defeat the
/// closed vocabulary [FontRole] exists to enforce.
final class CraftFonts {
  const CraftFonts({
    required this.sans,
    required this.serif,
    required this.mono,
  });

  /// The stack answering [FontRole.sans].
  final List<String> sans;

  /// The stack answering [FontRole.serif].
  final List<String> serif;

  /// The stack answering [FontRole.mono].
  final List<String> mono;

  /// The default binding: the platform's own UI, serif, and monospace faces.
  /// Costs no download and makes a surface look native to its host.
  static const CraftFonts systemUi = CraftFonts(
    sans: <String>[
      'system-ui',
      '-apple-system',
      'Segoe UI',
      'Roboto',
      'sans-serif',
    ],
    serif: <String>['Georgia', 'Times New Roman', 'serif'],
    mono: <String>[
      'ui-monospace',
      'SFMono-Regular',
      'Menlo',
      'Consolas',
      'monospace',
    ],
  );

  /// The family stack answering [role].
  List<String> forRole(FontRole role) => switch (role) {
        FontRole.sans => sans,
        FontRole.serif => serif,
        FontRole.mono => mono,
      };

  @override
  bool operator ==(Object other) =>
      other is CraftFonts &&
      _sameStack(other.sans, sans) &&
      _sameStack(other.serif, serif) &&
      _sameStack(other.mono, mono);

  @override
  int get hashCode => Object.hash(
        CraftFonts,
        Object.hashAll(sans),
        Object.hashAll(serif),
        Object.hashAll(mono),
      );

  @override
  String toString() => 'CraftFonts(sans: $sans, serif: $serif, mono: $mono)';

  static bool _sameStack(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
