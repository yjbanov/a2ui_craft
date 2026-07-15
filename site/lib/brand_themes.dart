// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `/primitives` page's **brand themes**: a color/type identity for the
/// rendered specimens (a real DTCG-token [CraftTheme], §9.5) paired with a page
/// chrome identity (CSS custom properties — the corners, border weights, and
/// fonts the semantic contract v1 doesn't carry).
///
/// Brand is an axis **orthogonal** to light/dark and to high-contrast: every
/// brand has a light and a dark scheme, and every brand answers the four n-ary
/// [CraftThemeMode]s. The site is the host here — hosts style their own chrome
/// and hand surfaces a theme — so these live in the site, not the core package
/// (which ships only the reference [DefaultTheme]).
library;

import 'dart:convert';

import 'package:a2ui_craft/a2ui_craft.dart'
    show
        CraftTheme,
        CraftThemeMode,
        DefaultTheme,
        DesignTokenSet,
        parseDesignTokens,
        resolveDesignTokens;

/// One (light or dark) color scheme of a brand: the page-chrome palette, from
/// which both the site CSS variables and the specimen [CraftTheme]'s role
/// tokens are derived (one source, so chrome and specimens never drift).
///
/// Every field is a `#RRGGBB` string.
class BrandScheme {
  const BrandScheme({
    required this.bg,
    required this.panel,
    required this.surface,
    required this.fg,
    required this.muted,
    required this.subtle,
    required this.faint,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.onPrimary,
    required this.link,
    required this.error,
    required this.onError,
  });

  final String bg;
  final String panel;
  final String surface;
  final String fg;
  final String muted;
  final String subtle;
  final String faint;
  final String border;
  final String borderStrong;
  final String primary;
  final String onPrimary;
  final String link;
  final String error;
  final String onError;

  /// The high-contrast intensifier (WCAG-AAA intent), mirroring the default
  /// theme's HC overlays: foreground and borders driven to the ceiling and the
  /// surfaces to pure black/white, while the brand accent is retained.
  BrandScheme toHighContrast(bool dark) {
    return BrandScheme(
      bg: dark ? '#000000' : '#FFFFFF',
      panel: dark ? '#0A0A0A' : '#F2F2F2',
      surface: dark ? '#000000' : '#FFFFFF',
      fg: dark ? '#FFFFFF' : '#000000',
      muted: dark ? '#F0F0F0' : '#1A1A1A',
      subtle: dark ? '#D8D8D8' : '#333333',
      faint: dark ? '#B0B0B0' : '#555555',
      border: dark ? '#FFFFFF' : '#000000',
      borderStrong: dark ? '#FFFFFF' : '#000000',
      primary: primary,
      onPrimary: onPrimary,
      link: link,
      error: error,
      onError: onError,
    );
  }
}

/// The brand geometry the color scheme can't express: the corner radii, border
/// weight, and font that give a brand its shape — the "creative with borders and
/// corners" axis, applied to the page chrome via CSS variables.
class BrandShape {
  const BrandShape({
    required this.cardRadius,
    required this.controlRadius,
    required this.borderWidth,
    required this.font,
  });

  /// Card / section corner radius, e.g. `'0'`, `'16px'`, `'22px'`.
  final String cardRadius;

  /// Segmented-control / input corner radius (`'999px'` = pill).
  final String controlRadius;

  /// Base chrome border weight in px (HC adds one).
  final double borderWidth;

  /// The chrome font stack.
  final String font;
}

/// A selectable brand: a name, its light + dark [BrandScheme]s, and its
/// [BrandShape]. The special [DefaultTheme]-backed brand ([isDefault]) reuses
/// the core reference theme for its specimens and clears all chrome overrides
/// (so the page renders exactly as the site's stock palette).
class Brand {
  const Brand({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
    required this.shape,
    this.isDefault = false,
  });

  final String id;

  /// The name shown in the picker segment.
  final String label;

  final BrandScheme light;
  final BrandScheme dark;
  final BrandShape shape;

  /// Whether this is the core reference theme (specimens use [DefaultTheme],
  /// chrome falls back to the site's stock CSS variables).
  final bool isDefault;

  static bool _isDark(CraftThemeMode mode) =>
      mode == CraftThemeMode.dark || mode == CraftThemeMode.darkHighContrast;

  static bool _isHighContrast(CraftThemeMode mode) =>
      mode == CraftThemeMode.lightHighContrast ||
      mode == CraftThemeMode.darkHighContrast;

  /// The resolved scheme for [mode] (base light/dark, then the HC intensifier).
  BrandScheme schemeFor(CraftThemeMode mode) {
    final bool dark = _isDark(mode);
    final BrandScheme base = dark ? this.dark : light;
    return _isHighContrast(mode) ? base.toHighContrast(dark) : base;
  }

  /// The specimen theme for [mode]: the core [DefaultTheme] for the default
  /// brand, else a DTCG-token theme built from this brand's scheme.
  CraftTheme craftTheme(CraftThemeMode mode) {
    if (isDefault) return DefaultTheme.of(mode);
    return _brandThemeCache
        .putIfAbsent((this, mode), () => _buildCraftTheme(schemeFor(mode)));
  }

  /// This brand as an inline **theme block** JSON string — the manifest theme
  /// shape `ProjectTheme.tryParse` understands: the base Light layer under
  /// `tokens`, plus a per-mode overlay for Dark and both high-contrast modes
  /// under `modes`. Empty for the default brand, which unthemes the surface (it
  /// blends into the host).
  ///
  /// The sample view drops this into the editable **Theme** tab when a brand is
  /// picked. It goes through the same [_colorBlock] token layer [craftTheme]
  /// resolves from, so parsing this JSON reproduces exactly [craftTheme] for
  /// every mode — what the editor shows is what the surface renders.
  String get themeJson {
    if (isDefault) return '';
    final Map<String, Object?> document = <String, Object?>{
      'tokens': <String, Object?>{
        'color': _colorBlock(schemeFor(CraftThemeMode.light),
            description: '$label — base layer (Light).'),
        'type': _typeScale,
      },
      'modes': <String, Object?>{
        for (final CraftThemeMode mode in const <CraftThemeMode>[
          CraftThemeMode.dark,
          CraftThemeMode.lightHighContrast,
          CraftThemeMode.darkHighContrast,
        ])
          mode.id: <String, Object?>{'color': _colorBlock(schemeFor(mode))},
      },
      'mode': CraftThemeMode.light.id,
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  /// The page-chrome CSS variables for [mode] — empty for the default brand
  /// (the stock `index.html` variables show through).
  Map<String, String> chromeVars(CraftThemeMode mode) {
    if (isDefault) return const <String, String>{};
    final BrandScheme s = schemeFor(mode);
    final double borderWidth =
        shape.borderWidth + (_isHighContrast(mode) ? 1.0 : 0.0);
    return <String, String>{
      '--bg': s.bg,
      '--panel': s.panel,
      '--card': s.surface,
      '--fg': s.fg,
      '--muted': s.muted,
      '--subtle': s.subtle,
      '--faint': s.faint,
      '--border': s.border,
      '--border-strong': s.borderStrong,
      '--accent': s.primary,
      '--accent-fg': s.onPrimary,
      '--card-radius': shape.cardRadius,
      '--control-radius': shape.controlRadius,
      '--card-border-width': '${borderWidth}px',
      '--card-border-color': s.border,
      '--brand-font': shape.font,
    };
  }

  static CraftTheme _buildCraftTheme(BrandScheme s) {
    // A one-layer DTCG document: the semantic color roles pointed straight at
    // the scheme's hexes (no palette indirection needed for a flat, single-mode
    // build), plus the stock type scale so the specimens read themed sizes.
    final Map<String, Object?> document = <String, Object?>{
      'color': _colorBlock(s),
      'type': _typeScale,
    };
    return CraftTheme(
        resolveDesignTokens(<DesignTokenSet>[parseDesignTokens(document)]));
  }

  /// The DTCG `color` token block for a scheme — the semantic roles pointed at
  /// the scheme's hexes. Shared by the resolved [craftTheme] (via
  /// [_buildCraftTheme]) and the editable [themeJson] so the two never drift.
  static Map<String, Object?> _colorBlock(BrandScheme s,
      {String? description}) {
    return <String, Object?>{
      r'$type': 'color',
      if (description != null) r'$description': description,
      'surface': <String, Object?>{r'$value': s.surface},
      'onSurface': <String, Object?>{r'$value': s.fg},
      'onSurfaceVariant': <String, Object?>{r'$value': s.muted},
      'primary': <String, Object?>{r'$value': s.primary},
      'onPrimary': <String, Object?>{r'$value': s.onPrimary},
      'outline': <String, Object?>{r'$value': s.border},
      'link': <String, Object?>{r'$value': s.link},
      'error': <String, Object?>{r'$value': s.error},
      'onError': <String, Object?>{r'$value': s.onError},
    };
  }

  static const Map<String, Object?> _typeScale = <String, Object?>{
    r'$type': 'dimension',
    'body': <String, Object?>{
      'size': <String, Object?>{r'$value': '14px'}
    },
    'caption': <String, Object?>{
      'size': <String, Object?>{r'$value': '12px'}
    },
    'heading': <String, Object?>{
      '1': <String, Object?>{
        'size': <String, Object?>{r'$value': '24px'}
      },
      '2': <String, Object?>{
        'size': <String, Object?>{r'$value': '22px'}
      },
      '3': <String, Object?>{
        'size': <String, Object?>{r'$value': '20px'}
      },
      '4': <String, Object?>{
        'size': <String, Object?>{r'$value': '18px'}
      },
      '5': <String, Object?>{
        'size': <String, Object?>{r'$value': '16px'}
      },
      '6': <String, Object?>{
        'size': <String, Object?>{r'$value': '14px'}
      },
    },
  };
}

/// One theme snapshot per (brand, mode) — resolution is cheap but the picker
/// re-reads on every mode/scheme flip, so we memoize.
final Map<(Brand, CraftThemeMode), CraftTheme> _brandThemeCache =
    <(Brand, CraftThemeMode), CraftTheme>{};

/// Every CSS variable any brand may set — the set the page clears when the
/// default brand is selected (or the screen unmounts), so the stock
/// `index.html` variables show through again.
const List<String> kChromeVarKeys = <String>[
  '--bg',
  '--panel',
  '--card',
  '--fg',
  '--muted',
  '--subtle',
  '--faint',
  '--border',
  '--border-strong',
  '--accent',
  '--accent-fg',
  '--card-radius',
  '--control-radius',
  '--card-border-width',
  '--card-border-color',
  '--brand-font',
];

/// The default (core reference) brand — first in the picker.
const Brand _defaultBrand = Brand(
  id: 'default',
  label: 'Default',
  isDefault: true,
  // Unused for the default brand (it defers to DefaultTheme + stock chrome),
  // but the fields are required; the site palette stands in.
  light: BrandScheme(
    bg: '#FFFFFF',
    panel: '#FAFAFA',
    surface: '#FFFFFF',
    fg: '#333333',
    muted: '#555555',
    subtle: '#888888',
    faint: '#BBBBBB',
    border: '#EEEEEE',
    borderStrong: '#CCCCCC',
    primary: '#1A73E8',
    onPrimary: '#FFFFFF',
    link: '#1A73E8',
    error: '#B3261E',
    onError: '#FFFFFF',
  ),
  dark: BrandScheme(
    bg: '#202124',
    panel: '#28292C',
    surface: '#2A2B2E',
    fg: '#E8EAED',
    muted: '#BDC1C6',
    subtle: '#9AA0A6',
    faint: '#5F6368',
    border: '#3C4043',
    borderStrong: '#5F6368',
    primary: '#8AB4F8',
    onPrimary: '#202124',
    link: '#8AB4F8',
    error: '#F2B8B5',
    onError: '#202124',
  ),
  shape: BrandShape(
    cardRadius: '16px',
    controlRadius: '6px',
    borderWidth: 1,
    font: 'system-ui, -apple-system, sans-serif',
  ),
);

/// **Terminal** — a phosphor-green console. Sharp 0px corners, a monospace
/// stack, paper-green in light and a classic black CRT in dark.
const Brand _terminalBrand = Brand(
  id: 'terminal',
  label: 'Terminal',
  light: BrandScheme(
    bg: '#EEF1EA',
    panel: '#E3E7DD',
    surface: '#F6F8F2',
    fg: '#1B2A1E',
    muted: '#3F5A44',
    subtle: '#6B7D6E',
    faint: '#9FB0A2',
    border: '#BAC8BB',
    borderStrong: '#8BA08E',
    primary: '#1F8F4E',
    onPrimary: '#FFFFFF',
    link: '#1F8F4E',
    error: '#B23B2E',
    onError: '#FFFFFF',
  ),
  dark: BrandScheme(
    bg: '#0B120D',
    panel: '#0F1A12',
    surface: '#101A13',
    fg: '#B9F7C6',
    muted: '#7FBF95',
    subtle: '#5F8F70',
    faint: '#3F5F4A',
    border: '#234A30',
    borderStrong: '#356B46',
    primary: '#39D353',
    onPrimary: '#06210E',
    link: '#6EE7A0',
    error: '#FF6B5E',
    onError: '#06210E',
  ),
  shape: BrandShape(
    cardRadius: '0',
    controlRadius: '0',
    borderWidth: 1,
    font: 'ui-monospace, SFMono-Regular, Menlo, monospace',
  ),
);

/// **Editorial** — a print magazine. Serif type, warm cream in light and warm
/// ink in dark, a burgundy accent (gold in dark), hairline 4px corners.
const Brand _editorialBrand = Brand(
  id: 'editorial',
  label: 'Editorial',
  light: BrandScheme(
    bg: '#F7F3EA',
    panel: '#EFE8D8',
    surface: '#FFFDF7',
    fg: '#26201A',
    muted: '#5C5147',
    subtle: '#857A6D',
    faint: '#B8AD9C',
    border: '#E0D6C4',
    borderStrong: '#C8B9A0',
    primary: '#8E2B2B',
    onPrimary: '#FFF7F0',
    link: '#8E2B2B',
    error: '#A3311F',
    onError: '#FFF7F0',
  ),
  dark: BrandScheme(
    bg: '#17130F',
    panel: '#1E1813',
    surface: '#201A14',
    fg: '#EFE6D6',
    muted: '#C3B6A2',
    subtle: '#938876',
    faint: '#5F574A',
    border: '#3A2F24',
    borderStrong: '#574836',
    primary: '#E0A458',
    onPrimary: '#241A0C',
    link: '#E6B877',
    error: '#EF8A6A',
    onError: '#241A0C',
  ),
  shape: BrandShape(
    cardRadius: '4px',
    controlRadius: '4px',
    borderWidth: 1,
    font: 'Georgia, "Times New Roman", serif',
  ),
);

/// **Bubblegum** — candy pop. Very round 22px corners and pill controls, thick
/// 2px borders, hot-pink accent over lavender in light and neon plum in dark.
const Brand _bubblegumBrand = Brand(
  id: 'bubblegum',
  label: 'Bubblegum',
  light: BrandScheme(
    bg: '#FDEEF7',
    panel: '#FBE0F0',
    surface: '#FFFAFD',
    fg: '#3A1030',
    muted: '#7A2E63',
    subtle: '#A95C92',
    faint: '#D69BC0',
    border: '#F3C6E2',
    borderStrong: '#E79CC9',
    primary: '#E5177F',
    onPrimary: '#FFFFFF',
    link: '#8B3CE0',
    error: '#E02749',
    onError: '#FFFFFF',
  ),
  dark: BrandScheme(
    bg: '#1B0F22',
    panel: '#261233',
    surface: '#29153A',
    fg: '#F6E6FF',
    muted: '#C7A3E0',
    subtle: '#9B6FC0',
    faint: '#6B4790',
    border: '#47276A',
    borderStrong: '#6A3A9C',
    primary: '#FF5DB1',
    onPrimary: '#2A0A1E',
    link: '#B78CFF',
    error: '#FF6B8A',
    onError: '#2A0A1E',
  ),
  shape: BrandShape(
    cardRadius: '22px',
    controlRadius: '999px',
    borderWidth: 2,
    font: '"Trebuchet MS", system-ui, sans-serif',
  ),
);

/// The brands offered by the `/primitives` picker, in order.
const List<Brand> kBrands = <Brand>[
  _defaultBrand,
  _terminalBrand,
  _editorialBrand,
  _bubblegumBrand,
];
