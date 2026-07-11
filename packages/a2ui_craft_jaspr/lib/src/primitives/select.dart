// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Select` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Select`: a single-choice dropdown over string `options` — the bare
/// control; label placement is a template's choice, like TextField. Two-way
/// bound: `onChanged` is a2ui_core's setter for the bound `value`. Shares the
/// TextField chrome roles; unthemed stays the native UA select (§9.1).
Component buildSelect(BuildContext context, DataSource source) {
  ensureCoreControlStyleSheet(coreControlStyleSheet);
  final List<String> options = stringList(source, 'options');
  final String? value = source.v<String>(['value']);
  final onChanged = source.handler<ValueChanged<String>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (String v) => trigger(<String, Object?>{'value': v}),
  );
  final String? outline = roleColor(context, ThemeRoles.outline);
  final String? accent = roleColor(context, ThemeRoles.primary);
  final String? ink = roleColor(context, ThemeRoles.onSurface);
  final bool unthemed = outline == null && accent == null && ink == null;
  return select(
    classes: outline == null ? null : 'craft-select',
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
          }),
    onChange: onChanged == null
        ? null
        : (List<String> values) {
            if (values.isNotEmpty) onChanged(values.first);
          },
    <Component>[
      for (final String o in options)
        // `selected:` on the matching option, not `value` on the select:
        // the select's value is applied before its options mount.
        option(value: o, selected: o == value, <Component>[
          Component.text(o),
        ]),
    ],
  );
}
