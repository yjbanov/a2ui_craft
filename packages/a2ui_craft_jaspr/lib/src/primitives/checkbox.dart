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
    classes: 'craft-checkbox',
    styles: _checkboxStyles(context, checked: value),
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
Styles? _checkboxStyles(BuildContext context, {required bool checked}) {
  final String? primary = roleColor(context, ThemeRoles.primary);
  if (primary == null) return null;
  final String border = roleColor(context, ThemeRoles.outline) ?? primary;
  final String mark = roleColor(context, ThemeRoles.onPrimary) ?? '#ffffff';
  return Styles(raw: <String, String>{
    'appearance': 'none',
    'width': '18px',
    'height': '18px',
    'margin': '0',
    'vertical-align': 'middle',
    'border': '2px solid ${checked ? primary : border}',
    'border-radius': '4px',
    'background-color': checked ? primary : 'transparent',
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
