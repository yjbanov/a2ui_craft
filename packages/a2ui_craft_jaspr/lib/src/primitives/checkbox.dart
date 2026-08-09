// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Checkbox` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Checkbox`: a two-way bound on/off box.
Component buildCheckbox(BuildContext context, DataSource source) {
  final bool value = source.v<bool>(['value']) ?? false;
  final onChanged = source.handler<ValueChanged<bool>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (bool v) => trigger(<String, Object?>{'value': v}),
  );
  // Toggle from the bound value rather than reading the event target, so the
  // handler works without a live DOM (e.g. in component tests).
  ensureCoreControlStyleSheet(coreControlStyleSheet);
  return input(
    type: InputType.checkbox,
    checked: value,
    // No `onChanged` → no value listener → the control cannot report changes,
    // so it is disabled, matching `Button`, `Slider`, and the Flutter
    // adapter's `Checkbox(onChanged: null)`. Without this the box was merely
    // *unwired*: still focusable, still announced as enabled, and a click
    // still flipped the native box on screen until the next rebuild put it
    // back — a control that looks live and silently isn't.
    disabled: onChanged == null,
    classes: 'craft-checkbox',
    styles:
        _checkboxStyles(context, checked: value, disabled: onChanged == null),
    events: onChanged == null
        ? null
        : <String, EventCallback>{'change': (_) => onChanged(!value)},
  );
}

/// The themed Checkbox glyph — adapter-owned painting (DESIGN.md §8).
///
/// Unthemed (no `primary`), the native UA checkbox is the web idiom's stock
/// look and the control blends in (§9.1): return null, exactly the
/// pre-contract DOM. Themed, `accent-color` can only *tint* the UA glyph —
/// it cannot fill per the role mapping — so the glyph is painted from
/// scratch (`appearance: none`): `outline` inks the box border, `primary`
/// fully fills the checked state, `onPrimary` draws the mark. The input is a
/// controlled element (re-rendered on every toggle), so the checked state
/// styles inline — no pseudo-classes needed.
///
/// [disabled] drops all three roles for `color.onSurface` at
/// [DisabledDefaults.foregroundAlpha] — fill and box edge alike, one flat
/// neutral where the enabled glyph plays `primary` against `outline` — with the
/// mark switching to `color.surface` so it still reads against that fill.
/// Fading the accent instead would leave a box that looks live in a lighter
/// shade; going neutral says the state outright.
Styles? _checkboxStyles(BuildContext context,
    {required bool checked, required bool disabled}) {
  final String? primary = roleColor(context, ThemeRoles.primary);
  if (primary == null) return null;
  // A theme may name `primary` and omit `onSurface`; with no neutral to go to,
  // keep the enabled palette rather than invent one.
  final String? neutral = roleColorAlpha(
      context, ThemeRoles.onSurface, DisabledDefaults.foregroundAlpha);
  final bool dim = disabled && neutral != null;
  final String fill = dim ? neutral : primary;
  final String border =
      dim ? neutral : roleColor(context, ThemeRoles.outline) ?? primary;
  final String mark = dim
      ? roleColor(context, ThemeRoles.surface) ?? kSurfaceFallback
      : roleColor(context, ThemeRoles.onPrimary) ?? '#ffffff';
  // The box geometry (size, corner, border width) is a framework-neutral
  // specified default (CheckboxDefaults) — read here, not hardcoded, so the web
  // glyph and any other painted glyph agree (DESIGN.md §8).
  final String size = '${px(CheckboxDefaults.size)}px';
  final String radius = '${px(CheckboxDefaults.cornerRadius.pixels)}px';
  final String width = '${px(CheckboxDefaults.borderWidth)}px';
  return Styles(raw: <String, String>{
    'appearance': 'none',
    'width': size,
    'height': size,
    'margin': '0',
    'vertical-align': 'middle',
    'border': '$width solid ${checked ? fill : border}',
    'border-radius': radius,
    'background-color': checked ? fill : 'transparent',
    if (checked) 'background-image': _checkmarkImage(mark),
    if (checked) 'background-size': '100% 100%',
  });
}

/// A checkmark as an inline SVG `background-image`, stroked with the resolved
/// [color] (URL-encoded — data URIs cannot reference CSS values).
String _checkmarkImage(String color) {
  final String stroke = Uri.encodeComponent(color);
  return 'url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' '
      'viewBox=\'0 0 24 24\'%3E%3Cpath fill=\'none\' stroke=\'$stroke\' '
      'stroke-width=\'4\' stroke-linecap=\'round\' stroke-linejoin=\'round\' '
      'd=\'M5 13l4 4L19 7\'/%3E%3C/svg%3E")';
}
