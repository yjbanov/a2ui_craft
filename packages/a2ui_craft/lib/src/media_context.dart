// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The **media context** — the render-time environment input for responsive UI
/// (research/responsive/RESPONSIVE_DESIGN.md). It is a *second render-time input
/// axis parallel to the theme mode* (DESIGN.md §9.5): the host measures the
/// viewport, quantizes it to a small shared vocabulary, and supplies it at render
/// time; primitives read it to restructure. It is an immutable snapshot — a
/// resize that crosses a class boundary supplies a *new* [MediaContext], which
/// re-renders in place (no remount) exactly like a re-theme.
///
/// The template never sees raw pixels: those are a cross-adapter hazard (device
/// pixel ratio, browser zoom, viewport jitter) and the road to `@media
/// (min-width: 733px)` magic numbers. The decision layer is a quantized **size
/// class**, identical on every adapter and host.
library;

import 'package:meta/meta.dart';

/// The window's **width** size class — the primary responsive axis — using the
/// Material 3 window size-class breakpoints. Ordered small → large; the ordinal
/// ([Enum.index]) is meaningful, so [atLeast] and the `Responsive` primitive's
/// nearest-smaller fallback can compare classes.
enum WindowSizeClass {
  /// Phones in portrait (M3: width < 600).
  compact('compact'),

  /// Large phones / small tablets, many phones in landscape (600–839).
  medium('medium'),

  /// Tablets, small laptops (840–1199).
  expanded('expanded'),

  /// Laptops and desktops (1200–1599).
  large('large'),

  /// Large desktops, TVs, and wall displays (≥ 1600).
  extraLarge('extraLarge');

  const WindowSizeClass(this.id);

  /// The token string a host/template uses to name this class.
  final String id;

  /// Whether this class is at least as wide as [other] (mobile-first
  /// comparison: `expanded.atLeast(medium)` is true).
  bool atLeast(WindowSizeClass other) => index >= other.index;

  /// Quantizes a logical-pixel [width] to a class using the **Material 3**
  /// window size-class breakpoints — the canonical host mapping, kept here so
  /// every host and adapter quantizes identically and no raw pixels reach a
  /// template.
  static WindowSizeClass forWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    if (width < 1200) return WindowSizeClass.expanded;
    if (width < 1600) return WindowSizeClass.large;
    return WindowSizeClass.extraLarge;
  }

  /// Decodes a class from its [id] string; unknown/absent yields [fallback]
  /// (default [compact] — mobile-first). Total, like every value-type decoder.
  static WindowSizeClass decode(Object? raw,
      {WindowSizeClass fallback = WindowSizeClass.compact}) {
    for (final WindowSizeClass c in values) {
      if (c.id == raw) return c;
    }
    return fallback;
  }

  /// The **mobile-first** selection a `Responsive` primitive makes for the
  /// current [width] among the classes it was [provided]: the largest provided
  /// class that is ≤ [width] (the breakpoint in effect); or, when [width] is
  /// smaller than every provided class, the smallest provided one. Returns null
  /// only when [provided] is empty.
  ///
  /// This lives in the core so both adapters resolve identically — a `Responsive`
  /// picks the *same* child on every adapter for a given size class (Pillar A:
  /// the primitives are a specification, not parallel implementations).
  static WindowSizeClass? resolveResponsive(
      WindowSizeClass width, Set<WindowSizeClass> provided) {
    if (provided.isEmpty) return null;
    WindowSizeClass? atOrBelow;
    WindowSizeClass? smallest;
    for (final WindowSizeClass c in provided) {
      if (smallest == null || c.index < smallest.index) smallest = c;
      if (c.index <= width.index &&
          (atOrBelow == null || c.index > atOrBelow.index)) {
        atOrBelow = c;
      }
    }
    return atOrBelow ?? smallest;
  }
}

/// The window's **height** size class (M3), a secondary axis carried for future
/// use (the `Responsive` primitive keys off [WindowSizeClass] for now).
enum WindowHeightClass {
  /// Short: phones in landscape (M3: height < 480).
  compact('compact'),

  /// Medium (480–899).
  medium('medium'),

  /// Tall (≥ 900).
  expanded('expanded');

  const WindowHeightClass(this.id);

  final String id;

  /// Quantizes a logical-pixel [height] to a class (M3 breakpoints).
  static WindowHeightClass forHeight(double height) {
    if (height < 480) return WindowHeightClass.compact;
    if (height < 900) return WindowHeightClass.medium;
    return WindowHeightClass.expanded;
  }

  static WindowHeightClass decode(Object? raw,
      {WindowHeightClass fallback = WindowHeightClass.medium}) {
    for (final WindowHeightClass c in values) {
      if (c.id == raw) return c;
    }
    return fallback;
  }
}

/// Portrait vs landscape — derivable cheaply from width/height, carried for
/// future use.
enum ScreenOrientation {
  portrait('portrait'),
  landscape('landscape');

  const ScreenOrientation(this.id);

  final String id;
}

/// An immutable snapshot of the render-time environment. Value equality drives
/// the reactivity model (a new snapshot with a different class re-renders the
/// dependents), the same contract as `CraftTheme`.
@immutable
class MediaContext {
  const MediaContext({
    required this.width,
    this.height = WindowHeightClass.medium,
    this.orientation = ScreenOrientation.portrait,
  });

  /// The width size class — the primary responsive axis.
  final WindowSizeClass width;

  /// The height size class (secondary, reserved).
  final WindowHeightClass height;

  /// Portrait or landscape (secondary, reserved).
  final ScreenOrientation orientation;

  @override
  bool operator ==(Object other) =>
      other is MediaContext &&
      other.width == width &&
      other.height == height &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(width, height, orientation);

  @override
  String toString() => 'MediaContext(width: ${width.id}, height: ${height.id}, '
      'orientation: ${orientation.id})';
}
