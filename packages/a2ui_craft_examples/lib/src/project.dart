// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_craft/a2ui_craft.dart';

/// The theme wiring of a project — the **4th trio file**, `theme.json`
/// (DESIGN.md §13.5 / §13.9). A project *names* its theme (theming is explicit);
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
