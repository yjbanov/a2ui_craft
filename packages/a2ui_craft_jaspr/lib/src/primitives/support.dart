// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Helpers shared by the core-primitive builders: argument decoding over the
/// framework-neutral value types, ambient theme-role lookups, CSS formatting,
/// the host-default fallback palette, and the shared control stylesheet.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';

// The state layer needs the document head, which only exists on the web;
// off-web (server-side rendering, tests) the install is a no-op.
export '../control_styles_stub.dart'
    if (dart.library.js_interop) '../control_styles_web.dart';

/// Reads a numeric argument, accepting an int or double literal.
double? numArg(DataSource source, String key) =>
    source.v<double>([key]) ?? source.v<int>([key])?.toDouble();

/// Gathers a raw inset value (a number or a list of numbers) from [source] so
/// the framework-neutral `Insets.decode` can interpret it. Only the extraction
/// is adapter-specific; the 2-vs-4-element interpretation lives in the core.
Object? insetsRaw(DataSource source, String key) {
  if (source.isList([key])) {
    final int n = source.length([key]);
    return <double>[
      for (int i = 0; i < n; i++)
        source.v<double>([key, i]) ??
            source.v<int>([key, i])?.toDouble() ??
            0.0,
    ];
  }
  return source.v<double>([key]) ?? source.v<int>([key])?.toDouble();
}

/// Gathers a raw `border` value (a width number, a `{width, color}` map, or a
/// bool) so the framework-neutral `BorderSpec.decode` can interpret it. Only the
/// extraction is adapter-specific; the interpretation lives in the core.
Object? borderRaw(DataSource source, String key) {
  if (source.isMap([key])) {
    return <String, Object?>{
      'width': source.v<double>([key, 'width']) ??
          source.v<int>([key, 'width'])?.toDouble(),
      'color': source.v<String>([key, 'color']),
    };
  }
  final bool? flag = source.v<bool>([key]);
  if (flag != null) return flag;
  return source.v<double>([key]) ?? source.v<int>([key])?.toDouble();
}

/// Reads a list-of-strings argument (e.g. a Select's `options`).
List<String> stringList(DataSource source, String key) {
  if (!source.isList([key])) return const <String>[];
  final int n = source.length([key]);
  return <String>[
    for (int i = 0; i < n; i++) source.v<String>([key, i]) ?? '',
  ];
}

/// Reads a role color from the ambient theme as a CSS color string, or null
/// when the surface is unthemed / the theme omits the role — the caller then
/// falls back to the host default (DESIGN.md §9.4).
String? roleColor(BuildContext context, String role) =>
    ambientCraftTheme(context)?.tokens.color(role)?.toCssString();

/// Reads a role size (a `dimension` token) as a CSS px length, or null for
/// the host default.
String? roleSize(BuildContext context, String role) {
  final double? px = ambientCraftTheme(context)?.tokens.dimension(role);
  return px == null ? null : '${numberToDisplayString(px)}px';
}

/// Renders a CSS length without a trailing `.0` for whole pixels.
String px(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Formats [i] as a CSS `top right bottom left` length list.
String cssInsets(Insets i) =>
    '${px(i.top)}px ${px(i.right)}px ${px(i.bottom)}px ${px(i.left)}px';

JustifyContent toJustify(MainAxisAlign a) => switch (a) {
      MainAxisAlign.start => JustifyContent.start,
      MainAxisAlign.center => JustifyContent.center,
      MainAxisAlign.end => JustifyContent.end,
      MainAxisAlign.spaceBetween => JustifyContent.spaceBetween,
      MainAxisAlign.spaceAround => JustifyContent.spaceAround,
      MainAxisAlign.spaceEvenly => JustifyContent.spaceEvenly,
    };

AlignItems toAlign(CrossAxisAlign a) => switch (a) {
      CrossAxisAlign.start => AlignItems.start,
      CrossAxisAlign.center => AlignItems.center,
      CrossAxisAlign.end => AlignItems.end,
      CrossAxisAlign.stretch => AlignItems.stretch,
    };

// Host-default fallback colors for the roles this adapter must paint even
// unthemed. Like Flutter's fallbacks (which resolve through `Theme.of` and so
// follow the host's dark mode), these must adapt to the page's effective
// color scheme — CSS `light-dark()` resolves against `color-scheme`, so a
// host page that declares `color-scheme: light dark` (or an explicit
// override) re-inks unthemed surfaces in dark mode instead of painting a
// light card under dark body text. On a page with no `color-scheme`
// declaration they resolve to the light value — the pre-dark-mode rendering.
const String kSurfaceFallback = 'light-dark(#ffffff, #2a2b2e)';
const String kDividerFallback =
    'light-dark(rgba(0, 0, 0, 0.12), rgba(255, 255, 255, 0.16))';
const String kCaptionFallback = 'light-dark(#5f6368, #9aa0a6)';
// The unthemed Button surface/ink pair — the same blue family as the link
// fallback, so the unthemed web idiom stays one palette. (The Flutter side
// resolves through `Theme.of(context).colorScheme.primary`/`onPrimary`
// instead: per-idiom latitude, DESIGN.md §8.)
const String kButtonSurfaceFallback = 'light-dark(#1a73e8, #8ab4f8)';
const String kButtonInkFallback = 'light-dark(#ffffff, #202124)';
// The Switch is always adapter-painted (no UA stock switch exists), so its
// off state needs scheme-adaptive fallbacks too.
const String kSwitchOffTrackFallback = 'light-dark(#c4c7c5, #5f6368)';
const String kSwitchOffThumbFallback = 'light-dark(#ffffff, #202124)';

/// The state layer (layer 2 of the control paint model, DESIGN.md §8) of the
/// core controls, as a stylesheet: hover/pressed feedback needs
/// pseudo-classes, which inline styles cannot express. Installed into the
/// document head by the first control build (idempotent; a no-op off-web).
/// The `:focus-visible` ring stays the UA default — never removed. Disabled
/// buttons get no visual dimming yet: samples still use handler-less buttons
/// as static decoration.
const String coreControlStyleSheet = '''
.craft-button:not(:disabled) { cursor: pointer; }
.craft-button:not(:disabled):hover { filter: brightness(0.94); }
.craft-button:not(:disabled):active { filter: brightness(0.86); }
.craft-checkbox:not(:disabled), .craft-radio:not(:disabled), .craft-switch:not(:disabled) { cursor: pointer; }
.craft-textfield:focus, .craft-select:focus { border-color: var(--craft-focus); }
.craft-textfield:focus-visible, .craft-select:focus-visible { outline: 2px solid var(--craft-focus); outline-offset: 1px; }
.craft-slider:not(:disabled) { cursor: pointer; }
.craft-slider:disabled { opacity: 0.5; cursor: not-allowed; }
.craft-slider::-webkit-slider-thumb { -webkit-appearance: none; appearance: none; width: 16px; height: 16px; border-radius: 50%; border: none; background: var(--craft-slider-thumb); }
.craft-slider::-moz-range-thumb { width: 16px; height: 16px; border-radius: 50%; border: none; background: var(--craft-slider-thumb); }
''';
