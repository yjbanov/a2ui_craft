// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:test/test.dart';

// The project theme — the 4th trio file (`theme.json`), DESIGN.md §9.5/§10:
// a project names its theme (a reference to the default theme + a mode, or an
// inline token set). Parsing is total; the host may open any available mode.

void main() {
  test('a default-theme reference parses with its mode and all modes offered',
      () {
    final ProjectTheme? theme =
        ProjectTheme.tryParse('{ "theme": "default", "mode": "dark" }');
    expect(theme, isNotNull);
    expect(theme!.usesDefaultTheme, isTrue);
    expect(theme.defaultMode, CraftThemeMode.dark);
    // The default theme is n-ary: the host may offer every mode.
    expect(theme.availableModes, CraftThemeMode.values);
    // resolve() opens the declared mode; an override opens another.
    expect(theme.resolve().tokens.color(ThemeRoles.surface),
        Rgba.decode('#202124'));
    expect(theme.resolve(CraftThemeMode.light).tokens.color(ThemeRoles.surface),
        Rgba.decode('#FFFFFF'));
  });

  test('a missing/unknown mode falls back to light', () {
    expect(ProjectTheme.tryParse('{ "theme": "default" }')!.defaultMode,
        CraftThemeMode.light);
    expect(
        ProjectTheme.tryParse('{ "theme": "default", "mode": "sepia" }')!
            .defaultMode,
        CraftThemeMode.light);
  });

  test('an inline token set is a single-layer theme with just its own mode',
      () {
    final ProjectTheme? theme = ProjectTheme.tryParse('''
      {
        "tokens": {
          "color": {
            "\$type": "color",
            "surface": { "\$value": "#123456" }
          }
        }
      }
    ''');
    expect(theme, isNotNull);
    expect(theme!.usesDefaultTheme, isFalse);
    expect(theme.availableModes, <CraftThemeMode>[CraftThemeMode.light]);
    expect(theme.resolve().tokens.color(ThemeRoles.surface),
        Rgba.decode('#123456'));
    // A mode override is ignored for an inline theme (it has one layer).
    expect(theme.resolve(CraftThemeMode.dark).tokens.color(ThemeRoles.surface),
        Rgba.decode('#123456'));
  });

  test('an inline theme with a dark overlay is two modes; overlay layers over',
      () {
    // The base + per-mode-overlay shape (DESIGN.md §9.5) inlined: the base is
    // Light; a "modes.dark" overlay merges over it before alias dereference.
    final ProjectTheme? theme = ProjectTheme.tryParse('''
      {
        "tokens": {
          "color": {
            "\$type": "color",
            "surface": { "\$value": "#FFF8F0" },
            "outline": { "\$value": "#E0CFC2" }
          }
        },
        "modes": {
          "dark": {
            "color": {
              "\$type": "color",
              "surface": { "\$value": "#2A1E17" }
            }
          },
          "sepia": { "color": {} }
        }
      }
    ''');
    expect(theme, isNotNull);
    expect(theme!.usesDefaultTheme, isFalse);
    expect(theme.defaultMode, CraftThemeMode.light);
    // The unknown "sepia" mode is ignored (totality).
    expect(theme.availableModes,
        <CraftThemeMode>[CraftThemeMode.light, CraftThemeMode.dark]);
    expect(theme.resolve().tokens.color(ThemeRoles.surface),
        Rgba.decode('#FFF8F0'));
    expect(theme.resolve(CraftThemeMode.dark).tokens.color(ThemeRoles.surface),
        Rgba.decode('#2A1E17'));
    // A role the overlay does not restate falls through to the base layer.
    expect(theme.resolve(CraftThemeMode.dark).tokens.color(ThemeRoles.outline),
        Rgba.decode('#E0CFC2'));
  });

  test('an inline theme may declare its default mode', () {
    final ProjectTheme? theme = ProjectTheme.tryParse('''
      {
        "tokens": { "color": { "\$type": "color",
                               "surface": { "\$value": "#FFFFFF" } } },
        "modes": { "dark": { "color": { "\$type": "color",
                                        "surface": { "\$value": "#000000" } } } },
        "mode": "dark"
      }
    ''');
    expect(theme!.defaultMode, CraftThemeMode.dark);
    expect(theme.resolve().tokens.color(ThemeRoles.surface),
        Rgba.decode('#000000'));
    // A declared mode with no matching layer falls back to light.
    final ProjectTheme? noLayer = ProjectTheme.tryParse('''
      { "tokens": { "color": {} }, "mode": "dark" }
    ''');
    expect(noLayer!.defaultMode, CraftThemeMode.light);
  });

  test('modeFor maps the system dark/light preference onto project modes', () {
    // The default theme offers both: the preference wins over the author's
    // default (host render-time config, DESIGN.md §9.5).
    final ProjectTheme deflt =
        ProjectTheme.tryParse('{ "theme": "default", "mode": "dark" }')!;
    expect(deflt.modeFor(dark: false), CraftThemeMode.light);
    expect(deflt.modeFor(dark: true), CraftThemeMode.dark);

    // An inline theme with a dark overlay follows the preference too.
    final ProjectTheme twoMode = ProjectTheme.tryParse('''
      { "tokens": { "color": {} }, "modes": { "dark": { "color": {} } } }
    ''')!;
    expect(twoMode.modeFor(dark: false), CraftThemeMode.light);
    expect(twoMode.modeFor(dark: true), CraftThemeMode.dark);

    // A single-layer theme has no dark to offer: the default mode stands.
    final ProjectTheme oneMode =
        ProjectTheme.tryParse('{ "tokens": { "color": {} } }')!;
    expect(oneMode.modeFor(dark: true), CraftThemeMode.light);
  });

  test('the calculator sample ships a custom-token theme (light + dark)', () {
    // The calculator is the one built-in that ships its own theme: it defines
    // custom tokens (theme.keypad.*) its template references by name — a demo
    // the brand picker can't replace (brands only cover the semantic contract).
    // Every other sample is now unthemed and recolored live from the picker.
    final ProjectTheme? theme = calculatorSpec('Jaspr').theme;
    expect(theme, isNotNull);
    expect(theme!.usesDefaultTheme, isFalse);
    expect(theme.availableModes,
        <CraftThemeMode>[CraftThemeMode.light, CraftThemeMode.dark]);
    expect(theme.resolve(CraftThemeMode.light).tokens.color(ThemeRoles.surface),
        Rgba.decode('#F8FAFC'));
    expect(theme.resolve(CraftThemeMode.dark).tokens.color(ThemeRoles.surface),
        Rgba.decode('#1E2126'));
  });

  test('null, blank, malformed, and unrecognized input parse to null (total)',
      () {
    expect(ProjectTheme.tryParse(null), isNull);
    expect(ProjectTheme.tryParse('   '), isNull);
    expect(ProjectTheme.tryParse('{ not json'), isNull);
    expect(ProjectTheme.tryParse('"a string"'), isNull);
    expect(ProjectTheme.tryParse('{ "theme": "acme-brand" }'), isNull);
  });

  test('the non-calculator samples carry no project theme', () {
    // They were unthemed as part of dropping per-sample brands in favor of the
    // live theme picker; only the calculator keeps a shipped (custom) theme.
    expect(counterSpec('Jaspr').theme, isNull);
    expect(profileCardSpec('Jaspr').theme, isNull);
    expect(weatherSpec('Jaspr').theme, isNull);
    expect(settingsSpec('Jaspr').theme, isNull);
  });

  group('ProjectManifest (the consolidated per-project manifest)', () {
    test('folds name, catalog id, and the theme reference into one document',
        () {
      final ProjectManifest m = ProjectManifest.parse('''
        {
          "name": "Profile Card",
          "catalogId": "demo",
          "theme": { "theme": "default", "mode": "dark" }
        }
      ''');
      expect(m.name, 'Profile Card');
      expect(m.catalogId, 'demo');
      expect(m.theme, isNotNull);
      expect(m.theme!.usesDefaultTheme, isTrue);
      expect(m.theme!.defaultMode, CraftThemeMode.dark);
    });

    test('name-only manifest: no catalog override, no theme', () {
      final ProjectManifest m = ProjectManifest.parse('{ "name": "Greeting" }');
      expect(m.name, 'Greeting');
      expect(m.catalogId, isNull);
      expect(m.theme, isNull);
    });

    test('malformed or partial input parses total (empty name, no theme)', () {
      expect(ProjectManifest.parse('{ not json').name, isEmpty);
      expect(ProjectManifest.parse('[]').name, isEmpty);
      expect(ProjectManifest.parse('{}').theme, isNull);
    });
  });
}
