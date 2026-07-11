// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `TextField` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `TextField`: the bare text input — no label. Label placement is a
/// template's choice (see DESIGN.md §4 "Bias to templatize" / §8), composed as
/// a separate Text.
Component buildTextField(BuildContext context, DataSource source) {
  // The `onChanged` arg is a2ui_core's two-way setter (a resolved callback),
  // accepted directly by the runtime's handler affordance.
  final onChanged = source.handler<ValueChanged<String>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (String value) => trigger(<String, Object?>{'value': value}),
  );
  // The role mapping (DESIGN.md §8), degrading role-by-role: `outline`
  // draws the box chrome (1px border, stock 6px corner, 8/12 padding),
  // `primary` the focus border + caret, `onSurface` the text ink. The
  // focus state needs pseudo-classes, so the chrome exports its color as
  // a custom property the control stylesheet reads. Fully unthemed, the
  // native UA field is the stock look (blend in, §9.1).
  ensureCoreControlStyleSheet(coreControlStyleSheet);
  final String? outline = roleColor(context, ThemeRoles.outline);
  final String? accent = roleColor(context, ThemeRoles.primary);
  final String? ink = roleColor(context, ThemeRoles.onSurface);
  final bool unthemed = outline == null && accent == null && ink == null;
  return input<String>(
    type: InputType.text,
    value: source.v<String>(['value']) ?? '',
    classes: outline == null ? null : 'craft-textfield',
    styles: unthemed
        ? null
        : Styles(raw: <String, String>{
            if (outline != null) ...<String, String>{
              'border': '1px solid $outline',
              'border-radius': '6px',
              'padding': '8px 12px',
              'background-color': 'transparent',
              'font': 'inherit',
              '--craft-focus': accent ?? outline,
            },
            if (ink != null) 'color': ink,
            if (accent != null) 'caret-color': accent,
          }),
    onInput: onChanged,
  );
}
