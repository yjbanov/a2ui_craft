// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:test/test.dart';

// The project theme — the 4th trio file (`theme.json`), DESIGN.md §13.5/§13.9:
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

  test('null, blank, malformed, and unrecognized input parse to null (total)',
      () {
    expect(ProjectTheme.tryParse(null), isNull);
    expect(ProjectTheme.tryParse('   '), isNull);
    expect(ProjectTheme.tryParse('{ not json'), isNull);
    expect(ProjectTheme.tryParse('"a string"'), isNull);
    expect(ProjectTheme.tryParse('{ "theme": "acme-brand" }'), isNull);
  });

  test('the profile_card sample is a themed project (default / dark)', () {
    final ProjectTheme? theme = profileCardSpec('Jaspr').theme;
    expect(theme, isNotNull);
    expect(theme!.usesDefaultTheme, isTrue);
    expect(theme.defaultMode, CraftThemeMode.dark);
  });

  test('an unthemed sample carries no project theme', () {
    expect(counterSpec('Jaspr').theme, isNull);
  });
}
