// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The open-source **default theme** (DESIGN.md §13.5): a base DTCG token layer
/// plus per-mode overlays, resolved for a host-supplied **n-ary mode** (light /
/// dark and their high-contrast variants — accessibility modes are first-class
/// axes, not a boolean flag).
///
/// It serves three jobs at once: the reference documentation of the semantic
/// contract ([ThemeRoles]), the starter kit authors fork for custom themes, and
/// the theming-conformance fixture. The runtime **never applies it unasked** —
/// theming is explicit (§13.1): a surface with no theme still blends into its
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

/// The render-time mode a host selects for the default theme.
///
/// N-ary by design (§13.5): dark and high-contrast are orthogonal accessibility
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
/// wiring. This wiring is **ours**, kept out of the token files (§13.5): DTCG's
/// own multi-mode answer is still an unstable draft, so we mirror its model
/// (sets + resolution order) behind our own config and can conform later.
final class DefaultThemeManifest {
  const DefaultThemeManifest._(this.name, this.description, this._modes);

  /// The theme's display name.
  final String name;

  /// A one-line description of the theme.
  final String description;

  final Map<String, List<String>> _modes;

  /// The ordered set names (lowest → highest precedence) to resolve for the
  /// mode whose manifest key is [modeId]; empty for an unknown mode.
  List<String> resolutionOrder(String modeId) =>
      _modes[modeId] ?? const <String>[];

  static DefaultThemeManifest _parse(String json) {
    final Map<String, Object?> m = jsonDecode(json) as Map<String, Object?>;
    final Map<String, Object?> modes = m['modes'] as Map<String, Object?>;
    return DefaultThemeManifest._(
      m['name'] as String,
      m['description'] as String? ?? '',
      <String, List<String>>{
        for (final MapEntry<String, Object?> e in modes.entries)
          e.key: (e.value as List<Object?>).cast<String>(),
      },
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

  static final Map<CraftThemeMode, CraftTheme> _cache =
      <CraftThemeMode, CraftTheme>{};

  /// The default theme resolved for [mode], as an immutable [CraftTheme] a host
  /// hands to a surface. Cached — the same mode returns the same snapshot.
  static CraftTheme of(CraftThemeMode mode) =>
      _cache.putIfAbsent(mode, () => _build(mode));

  static CraftTheme _build(CraftThemeMode mode) {
    final List<String> order = manifest.resolutionOrder(mode.id);
    return CraftTheme(resolveDesignTokens(<DesignTokenSet>[
      for (final String set in order) _sets[set] ?? DesignTokenSet.empty,
    ]));
  }
}
