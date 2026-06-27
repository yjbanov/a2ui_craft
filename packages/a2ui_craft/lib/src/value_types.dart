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
