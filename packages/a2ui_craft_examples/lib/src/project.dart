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
/// * `{ "tokens": { …DTCG… } }` — an inline single-layer theme (its own tokens,
///   no modes); the escape hatch for a project that ships bespoke tokens rather
///   than referencing the default theme.
///
/// This is the theme-reference-plus-mode-wiring portion of the eventual project
/// manifest; the name and catalog id already live alongside the trio (a sample's
/// `label` and the shared `catalogId`).
class ProjectTheme {
  const ProjectTheme._({
    required this.usesDefaultTheme,
    required this.defaultMode,
    ResolvedTokens? inline,
  }) : _inline = inline;

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
      return ProjectTheme._(
        usesDefaultTheme: false,
        defaultMode: CraftThemeMode.light,
        inline:
            resolveDesignTokens(<DesignTokenSet>[parseDesignTokens(tokens)]),
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
  /// of its modes); false for an inline single-layer theme.
  final bool usesDefaultTheme;

  /// The project's default (and, for an inline theme, only) mode.
  final CraftThemeMode defaultMode;

  final ResolvedTokens? _inline;

  /// The modes a host may offer for this project: every [CraftThemeMode] for the
  /// default theme, or just [defaultMode] for an inline theme.
  List<CraftThemeMode> get availableModes =>
      usesDefaultTheme ? CraftThemeMode.values : <CraftThemeMode>[defaultMode];

  /// Resolves an immutable [CraftTheme] snapshot for [mode] (defaulting to
  /// [defaultMode]). An inline theme has a single layer and ignores [mode].
  CraftTheme resolve([CraftThemeMode? mode]) => usesDefaultTheme
      ? DefaultTheme.of(mode ?? defaultMode)
      : CraftTheme(_inline!);

  static CraftThemeMode? _modeByName(Object? name) {
    for (final CraftThemeMode mode in CraftThemeMode.values) {
      if (mode.id == name) return mode;
    }
    return null;
  }
}
