// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The open-source **default theme** (DESIGN.md §9.5): a base DTCG token layer
/// plus per-mode overlays, resolved for a host-supplied **n-ary mode** (light /
/// dark and their high-contrast variants — accessibility modes are first-class
/// axes, not a boolean flag).
///
/// It serves three jobs at once: the reference documentation of the semantic
/// contract ([ThemeRoles]), the starter kit authors fork for custom themes, and
/// the theming-conformance fixture. The runtime **never applies it unasked** —
/// theming is explicit (§9.1): a surface with no theme still blends into its
/// host. A host that *wants* it calls [DefaultTheme.of] and hands the resulting
/// [CraftTheme] to a surface; flipping [CraftThemeMode] is just handing over the
/// next (cached, immutable) snapshot — the surface re-themes in place.
///
/// The token `.json` files under `lib/src/themes/default/` are the editable
/// source of truth; `default_theme.g.dart` bakes them in for zero-IO loading.
library;

import 'dart:convert';

import 'default_theme.g.dart';
import 'design_tokens.dart';
import 'media_context.dart';

/// The render-time mode a host selects for the default theme.
///
/// N-ary by design (§9.5): dark and high-contrast are orthogonal accessibility
/// axes, not one boolean. Each value's [name] is its key in the theme
/// manifest's `modes` map (the resolution order for that mode).
enum CraftThemeMode {
  /// The base layer alone — restates the primitives' pre-contract look.
  light('Light'),

  /// Dark surfaces with light foreground.
  dark('Dark'),

  /// Light mode, contrast pushed to the accessibility ceiling.
  lightHighContrast('Light · High contrast'),

  /// Dark mode, contrast pushed to the accessibility ceiling.
  darkHighContrast('Dark · High contrast');

  const CraftThemeMode(this.label);

  /// A human-facing name for a mode picker.
  final String label;

  /// The manifest `modes` key for this mode (mirrors [name]).
  String get id => name;
}

/// The default theme's manifest: its name and the mode → resolution-order
/// wiring. This wiring is **ours**, kept out of the token files (§9.5): DTCG's
/// own multi-mode answer is still an unstable draft, so we mirror its model
/// (sets + resolution order) behind our own config and can conform later.
final class DefaultThemeManifest {
  const DefaultThemeManifest._(
      this.name, this.description, this._modes, this._sizeClasses);

  /// The theme's display name.
  final String name;

  /// A one-line description of the theme.
  final String description;

  final Map<String, List<String>> _modes;
  final Map<String, List<String>> _sizeClasses;

  /// The ordered set names (lowest → highest precedence) to resolve for the
  /// mode whose manifest key is [modeId]; empty for an unknown mode.
  List<String> resolutionOrder(String modeId) =>
      _modes[modeId] ?? const <String>[];

  /// The size-class overlay set names to append (over the mode order) for the
  /// window size class whose manifest key is [sizeClassId] — the second axis of
  /// the cascade (mode × size class, §9.5 / RESPONSIVE_DESIGN.md §4.4). Empty
  /// for the base classes (compact/medium) and any unknown class, so a theme
  /// with no `sizeClasses` block resolves exactly as before.
  List<String> sizeClassOrder(String sizeClassId) =>
      _sizeClasses[sizeClassId] ?? const <String>[];

  static DefaultThemeManifest _parse(String json) {
    final Map<String, Object?> m = jsonDecode(json) as Map<String, Object?>;
    final Map<String, Object?> modes = m['modes'] as Map<String, Object?>;
    final Object? sizeClasses = m['sizeClasses'];
    return DefaultThemeManifest._(
      m['name'] as String,
      m['description'] as String? ?? '',
      <String, List<String>>{
        for (final MapEntry<String, Object?> e in modes.entries)
          e.key: (e.value as List<Object?>).cast<String>(),
      },
      sizeClasses is Map<String, Object?>
          ? <String, List<String>>{
              for (final MapEntry<String, Object?> e in sizeClasses.entries)
                e.key: (e.value as List<Object?>).cast<String>(),
            }
          : const <String, List<String>>{},
    );
  }
}

/// The open-source default theme, resolved per [CraftThemeMode].
///
/// Snapshots are immutable and built once per mode (resolution is a cheap map
/// build); [of] caches them. The token layers parse once on first use.
abstract final class DefaultTheme {
  /// The theme manifest (name and mode wiring).
  static final DefaultThemeManifest manifest =
      DefaultThemeManifest._parse(defaultThemeManifestJson);

  static final Map<String, DesignTokenSet> _sets = <String, DesignTokenSet>{
    for (final MapEntry<String, String> e in defaultThemeSetJson.entries)
      e.key: parseDesignTokens(jsonDecode(e.value)),
  };

  static final Map<(CraftThemeMode, WindowSizeClass), CraftTheme> _cache =
      <(CraftThemeMode, WindowSizeClass), CraftTheme>{};

  /// The default theme resolved for [mode] and [sizeClass], as an immutable
  /// [CraftTheme] a host hands to a surface. Cached — the same pair returns the
  /// same snapshot.
  ///
  /// [sizeClass] is the second overlay axis (RESPONSIVE_DESIGN.md §4.4): the
  /// mode overlay re-points colour, the size-class overlay bumps proportioning
  /// (the type scale — a larger screen wants a bigger ramp). It defaults to
  /// [WindowSizeClass.compact] (the base scale), so a host that ignores
  /// responsiveness sees exactly the previous behaviour.
  static CraftTheme of(CraftThemeMode mode,
          {WindowSizeClass sizeClass = WindowSizeClass.compact}) =>
      _cache.putIfAbsent((mode, sizeClass), () => _build(mode, sizeClass));

  static CraftTheme _build(CraftThemeMode mode, WindowSizeClass sizeClass) {
    // Resolution order = the mode's layers, then the size class's overlay on
    // top (colour then proportioning), merged once before alias dereference.
    final List<String> order = <String>[
      ...manifest.resolutionOrder(mode.id),
      ...manifest.sizeClassOrder(sizeClass.id),
    ];
    return CraftTheme(resolveDesignTokens(<DesignTokenSet>[
      for (final String set in order) _sets[set] ?? DesignTokenSet.empty,
    ]));
  }
}
