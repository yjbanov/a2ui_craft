// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

// The open-source default theme (DESIGN.md §9.5, slice 4): the base layer plus
// per-mode overlays resolve, per the host-supplied n-ary mode, into a complete
// set of the semantic-contract roles. These are pure-Dart data assertions; the
// cross-adapter *painting* of these values on a live surface (and the reactive
// mode swap) is pinned by the conformance suite.

/// The color roles every mode must supply (nothing drops through to a host
/// default) — the consumed roles plus the reserved-but-defined ones.
const List<String> _colorRoles = <String>[
  ThemeRoles.surface,
  ThemeRoles.onSurface,
  ThemeRoles.onSurfaceVariant,
  ThemeRoles.primary,
  ThemeRoles.onPrimary,
  ThemeRoles.outline,
  ThemeRoles.link,
  ThemeRoles.error,
  ThemeRoles.onError,
];

Rgba _hex(String s) => Rgba.decode(s)!;

void main() {
  group('Light mode restates the pre-contract look', () {
    // Applying the default theme in Light must reproduce the exact values the
    // primitives hardcoded before the semantic contract existed (§9.4), so a
    // surface looks the same whether it was unthemed or freshly themed Light.
    final ResolvedTokens t = DefaultTheme.of(CraftThemeMode.light).tokens;

    test('caption/link colors match the old hardcoded literals', () {
      expect(t.color(ThemeRoles.onSurfaceVariant), _hex('#5F6368'));
      expect(t.color(ThemeRoles.link), _hex('#1A73E8'));
    });

    test('surface is white, ink is near-black', () {
      expect(t.color(ThemeRoles.surface), _hex('#FFFFFF'));
      expect(t.color(ThemeRoles.onSurface), _hex('#202124'));
    });

    test('the type scale matches the built-in ramp', () {
      expect(t.dimension(ThemeRoles.bodySize), 14);
      expect(t.dimension(ThemeRoles.captionSize), 12);
      expect(<double?>[
        for (int l = 1; l <= 6; l++) t.dimension(ThemeRoles.headingSize(l))
      ], <double>[
        24,
        22,
        20,
        18,
        16,
        14
      ]);
    });
  });

  test('every mode supplies every contract role (no dropped tokens)', () {
    // Totality/completeness: whatever the mode, the aliases dereference to a
    // concrete value for every color role and every heading size, so no
    // primitive ever falls through to a host default under the default theme.
    for (final CraftThemeMode mode in CraftThemeMode.values) {
      final ResolvedTokens t = DefaultTheme.of(mode).tokens;
      for (final String role in _colorRoles) {
        expect(t.color(role), isNotNull, reason: '$role missing in ${mode.id}');
      }
      expect(t.dimension(ThemeRoles.bodySize), isNotNull);
      expect(t.dimension(ThemeRoles.captionSize), isNotNull);
      for (int level = 1; level <= 6; level++) {
        expect(t.dimension(ThemeRoles.headingSize(level)), isNotNull,
            reason: 'heading $level missing in ${mode.id}');
      }
    }
  });

  test('the type scale is invariant across modes (only color changes)', () {
    // Role names — and the type ramp — never change across modes (§9.5); only
    // the color layer re-points.
    List<double?> ramp(CraftThemeMode m) {
      final ResolvedTokens t = DefaultTheme.of(m).tokens;
      return <double?>[
        t.dimension(ThemeRoles.bodySize),
        t.dimension(ThemeRoles.captionSize),
        for (int l = 1; l <= 6; l++) t.dimension(ThemeRoles.headingSize(l)),
      ];
    }

    final List<double?> light = ramp(CraftThemeMode.light);
    for (final CraftThemeMode mode in CraftThemeMode.values) {
      expect(ramp(mode), light, reason: '${mode.id} changed the type scale');
    }
  });

  test('Dark re-points surface/ink and differs from Light', () {
    final ResolvedTokens light = DefaultTheme.of(CraftThemeMode.light).tokens;
    final ResolvedTokens dark = DefaultTheme.of(CraftThemeMode.dark).tokens;

    // Dark surface is dark, ink is light — the inverse of Light.
    expect(dark.color(ThemeRoles.surface), _hex('#202124'));
    expect(dark.color(ThemeRoles.onSurface), _hex('#F8F9FA'));
    expect(
        dark.color(ThemeRoles.surface), isNot(light.color(ThemeRoles.surface)));
    expect(dark.color(ThemeRoles.onSurface),
        isNot(light.color(ThemeRoles.onSurface)));
  });

  test('high-contrast modes push ink and border to the extremes', () {
    final ResolvedTokens lhc =
        DefaultTheme.of(CraftThemeMode.lightHighContrast).tokens;
    final ResolvedTokens dhc =
        DefaultTheme.of(CraftThemeMode.darkHighContrast).tokens;

    // Light HC: pure-black ink over the (unchanged) white surface.
    expect(lhc.color(ThemeRoles.onSurface), _hex('#000000'));
    expect(lhc.color(ThemeRoles.surface), _hex('#FFFFFF'));

    // Dark HC composes over Dark (base → dark → dark-high-contrast): pure-black
    // surface, pure-white ink — the deltas the overlay carries.
    expect(dhc.color(ThemeRoles.surface), _hex('#000000'));
    expect(dhc.color(ThemeRoles.onSurface), _hex('#FFFFFF'));
  });

  group('manifest', () {
    test('exposes the mode → resolution-order wiring', () {
      expect(DefaultTheme.manifest.name, 'A2UI Craft Default');
      expect(DefaultTheme.manifest.resolutionOrder('light'), <String>['base']);
      expect(DefaultTheme.manifest.resolutionOrder('darkHighContrast'),
          <String>['base', 'dark', 'darkHighContrast']);
    });

    test('an unknown mode resolves to nothing (total)', () {
      expect(DefaultTheme.manifest.resolutionOrder('sepia'), isEmpty);
    });

    test('every enum mode is wired in the manifest', () {
      for (final CraftThemeMode mode in CraftThemeMode.values) {
        expect(DefaultTheme.manifest.resolutionOrder(mode.id), isNotEmpty,
            reason: '${mode.id} not wired');
      }
    });
  });

  test('of() returns a cached, stable snapshot per mode', () {
    expect(
        identical(DefaultTheme.of(CraftThemeMode.dark),
            DefaultTheme.of(CraftThemeMode.dark)),
        isTrue);
  });
}
