// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_craft/a2ui_craft.dart';

/// A project's consolidated manifest — its `manifest.json` (DESIGN.md §10):
/// the container config for the ephemeral bundle, holding everything *about*
/// the project that isn't one of its trio files.
///
/// v1 fields: [name] (display name), [catalogId] (which component catalog the
/// project targets — null means the host/default catalog), and [theme] (the
/// theme reference + mode wiring, a [ProjectTheme]). Ephemeral business logic
/// gets a slot here later (ROADMAP.md), empty for now. Parsing is total: a malformed or
/// partial manifest yields empty/absent fields rather than throwing.
class ProjectManifest {
  const ProjectManifest({
    required this.name,
    this.catalogId,
    this.theme,
  });

  /// Parses a project `manifest.json` string. Total — malformed input yields an
  /// empty [name] and no catalog/theme.
  static ProjectManifest parse(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      decoded = null;
    }
    final Map<String, Object?> m =
        decoded is Map<String, Object?> ? decoded : const <String, Object?>{};
    final Object? name = m['name'];
    final Object? catalogId = m['catalogId'];
    final Object? theme = m['theme'];
    return ProjectManifest(
      name: name is String ? name : '',
      catalogId: catalogId is String ? catalogId : null,
      // The theme block is a nested ProjectTheme config; re-encode and reuse the
      // one parser so the manifest and a standalone theme file agree.
      theme: theme == null ? null : ProjectTheme.tryParse(jsonEncode(theme)),
    );
  }

  /// The project's display name.
  final String name;

  /// The component catalog the project targets, or null for the host default.
  final String? catalogId;

  /// The project's theme (reference + mode wiring), or null when it ships none.
  final ProjectTheme? theme;
}

/// The theme wiring of a project — the **4th trio file**, `theme.json`
/// (DESIGN.md §9.5 / §10). A project *names* its theme (theming is explicit);
/// a project with no `theme.json` has no [ProjectTheme] and blends into the host.
///
/// Two shapes are recognized (everything else — including malformed JSON —
/// parses to null, so a project silently stays unthemed):
///
/// * `{ "theme": "default", "mode": "dark" }` — the open-source [DefaultTheme],
///   opened in the named [CraftThemeMode]. The mode is the project's *default*;
///   because the default theme is n-ary, a host may offer any of its
///   [availableModes] at render time.
/// * `{ "tokens": { …DTCG… }, "modes": { "dark": { …DTCG overlay… } },
///   "mode": "dark" }` — an inline **custom theme**: a base DTCG token layer
///   (which is the Light mode) plus optional per-mode overlay layers, each
///   merged over the base before alias dereference — the base + per-mode-overlay
///   shape of DESIGN.md §9.5, inlined into the manifest. `modes` and `mode`
///   are optional; a bare `{ "tokens": … }` is a single-layer theme.
///
/// This is the theme-reference-plus-mode-wiring portion of the project
/// manifest; the name and catalog id are the manifest's other fields.
class ProjectTheme {
  const ProjectTheme._({
    required this.usesDefaultTheme,
    required this.defaultMode,
    Map<CraftThemeMode, ResolvedTokens> inline =
        const <CraftThemeMode, ResolvedTokens>{},
    Map<(CraftThemeMode, WindowSizeClass), ResolvedTokens> responsive =
        const <(CraftThemeMode, WindowSizeClass), ResolvedTokens>{},
  })  : _inline = inline,
        _responsive = responsive;

  /// Parses a `theme.json` string; null/blank/unrecognized/malformed → null.
  static ProjectTheme? tryParse(String? themeJson) {
    if (themeJson == null || themeJson.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(themeJson);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;

    final Object? tokens = decoded['tokens'];
    if (tokens != null) {
      final DesignTokenSet base = parseDesignTokens(tokens);
      // The per-mode overlay sets (light has none — it is the base), kept raw so
      // the size-class overlay can compose over them. Unknown mode names and
      // non-map overlays are ignored (totality).
      final Map<CraftThemeMode, DesignTokenSet> modeSets =
          <CraftThemeMode, DesignTokenSet>{};
      final Object? modes = decoded['modes'];
      if (modes is Map<String, Object?>) {
        for (final MapEntry<String, Object?> entry in modes.entries) {
          final CraftThemeMode? mode = _modeByName(entry.key);
          if (mode == null || entry.value is! Map<String, Object?>) continue;
          modeSets[mode] = parseDesignTokens(entry.value);
        }
      }
      // The per-size-class overlay sets, likewise raw. Unknown class ids and
      // non-map overlays are ignored (totality). RESPONSIVE_DESIGN.md §4.4.
      final Map<WindowSizeClass, DesignTokenSet> classSets =
          <WindowSizeClass, DesignTokenSet>{};
      final Object? sizeClasses = decoded['sizeClasses'];
      if (sizeClasses is Map<String, Object?>) {
        for (final MapEntry<String, Object?> entry in sizeClasses.entries) {
          final WindowSizeClass? cls = _sizeClassByName(entry.key);
          if (cls == null || entry.value is! Map<String, Object?>) continue;
          classSets[cls] = parseDesignTokens(entry.value);
        }
      }

      // Resolve each layer stack once, merge-then-dereference so an overlay
      // re-points the roles it names: base (Light) alone, then each mode over
      // the base, then each (mode, size class) with the size-class overlay on
      // top of the mode.
      final Map<CraftThemeMode, ResolvedTokens> inline =
          <CraftThemeMode, ResolvedTokens>{
        CraftThemeMode.light: resolveDesignTokens(<DesignTokenSet>[base]),
        for (final MapEntry<CraftThemeMode, DesignTokenSet> e
            in modeSets.entries)
          e.key: resolveDesignTokens(<DesignTokenSet>[base, e.value]),
      };
      final Map<(CraftThemeMode, WindowSizeClass), ResolvedTokens> responsive =
          <(CraftThemeMode, WindowSizeClass), ResolvedTokens>{
        for (final CraftThemeMode mode in inline.keys)
          for (final MapEntry<WindowSizeClass, DesignTokenSet> ce
              in classSets.entries)
            (mode, ce.key): resolveDesignTokens(<DesignTokenSet>[
              base,
              if (modeSets[mode] != null) modeSets[mode]!,
              ce.value,
            ]),
      };
      final CraftThemeMode? declared = _modeByName(decoded['mode']);
      return ProjectTheme._(
        usesDefaultTheme: false,
        defaultMode: declared != null && inline.containsKey(declared)
            ? declared
            : CraftThemeMode.light,
        inline: inline,
        responsive: responsive,
      );
    }
    if (decoded['theme'] == 'default') {
      return ProjectTheme._(
        usesDefaultTheme: true,
        defaultMode: _modeByName(decoded['mode']) ?? CraftThemeMode.light,
      );
    }
    return null;
  }

  /// True when this references the built-in [DefaultTheme] (and so exposes all
  /// of its modes); false for an inline custom theme.
  final bool usesDefaultTheme;

  /// The project's default mode.
  final CraftThemeMode defaultMode;

  /// For an inline theme: the resolved token snapshot per available mode (at the
  /// base — compact/medium — size class).
  final Map<CraftThemeMode, ResolvedTokens> _inline;

  /// For an inline theme with a `sizeClasses` block: the resolved snapshot per
  /// (mode, size class) where a size-class overlay applies — the second cascade
  /// axis (RESPONSIVE_DESIGN.md §4.4). A pair with no entry falls back to the
  /// base-scale [_inline] for that mode, so a theme without the block is
  /// unaffected.
  final Map<(CraftThemeMode, WindowSizeClass), ResolvedTokens> _responsive;

  /// The modes a host may offer for this project: every [CraftThemeMode] for
  /// the default theme; for an inline theme, the base (Light) plus each mode
  /// with an overlay — in [CraftThemeMode] declaration order.
  List<CraftThemeMode> get availableModes => usesDefaultTheme
      ? CraftThemeMode.values
      : <CraftThemeMode>[
          for (final CraftThemeMode mode in CraftThemeMode.values)
            if (_inline.containsKey(mode)) mode,
        ];

  /// The project mode matching the host's system dark/light preference: the
  /// plain [CraftThemeMode.light] / [CraftThemeMode.dark] when the project
  /// offers it, else [defaultMode]. This is host render-time configuration
  /// (DESIGN.md §9.5) — the author's `mode` stays the fallback.
  CraftThemeMode modeFor({required bool dark}) {
    final CraftThemeMode preferred =
        dark ? CraftThemeMode.dark : CraftThemeMode.light;
    return availableModes.contains(preferred) ? preferred : defaultMode;
  }

  /// Resolves an immutable [CraftTheme] snapshot for [mode] (defaulting to
  /// [defaultMode]) and [sizeClass] — the second cascade axis
  /// (RESPONSIVE_DESIGN.md §4.4). [sizeClass] defaults to
  /// [WindowSizeClass.compact] (the base scale), so a host that ignores
  /// responsiveness resolves exactly as before.
  ///
  /// An inline theme falls back to its base-scale snapshot for a (mode, class)
  /// with no size-class overlay, then to its Light base for a mode with no
  /// overlay.
  CraftTheme resolve(
      [CraftThemeMode? mode,
      WindowSizeClass sizeClass = WindowSizeClass.compact]) {
    final CraftThemeMode m = mode ?? defaultMode;
    if (usesDefaultTheme) return DefaultTheme.of(m, sizeClass: sizeClass);
    return CraftTheme(_responsive[(m, sizeClass)] ??
        _inline[m] ??
        _inline[CraftThemeMode.light] ??
        ResolvedTokens.empty);
  }

  static CraftThemeMode? _modeByName(Object? name) {
    for (final CraftThemeMode mode in CraftThemeMode.values) {
      if (mode.id == name) return mode;
    }
    return null;
  }

  static WindowSizeClass? _sizeClassByName(Object? name) {
    for (final WindowSizeClass cls in WindowSizeClass.values) {
      if (cls.id == name) return cls;
    }
    return null;
  }
}
