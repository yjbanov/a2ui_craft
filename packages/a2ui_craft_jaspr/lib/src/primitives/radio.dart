// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Radio` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Radio`: a single radio button that shows `selected` and fires
/// `onChanged` when tapped ("select me"). Grouping — which radio is on — is
/// the template's job.
// TODO(a2ui-craft): revisit alongside the Flutter Radio (see the Flutter
// adapter) so the two stay behaviorally aligned — e.g. native radio grouping
// and the `change` vs `click` event choice.
Component buildRadio(BuildContext context, DataSource source) {
  final bool selected = source.v<bool>(['selected']) ?? false;
  final onChanged = source.voidHandler(['onChanged']);
  ensureCoreControlStyleSheet(coreControlStyleSheet);
  return input(
    type: InputType.radio,
    checked: selected,
    classes: 'craft-radio',
    styles: _radioStyles(context, selected: selected),
    events: onChanged == null
        ? null
        : <String, EventCallback>{'click': (_) => onChanged()},
  );
}

/// The themed Radio glyph; same contract as the Checkbox's painted glyph —
/// `outline` rings the unselected circle, `primary` inks the selected ring
/// and dot. Unthemed (no `primary`) returns null: the native UA radio is the
/// stock look (blend in, §9.1).
Styles? _radioStyles(BuildContext context, {required bool selected}) {
  final String? primary = roleColor(context, ThemeRoles.primary);
  if (primary == null) return null;
  final String border = roleColor(context, ThemeRoles.outline) ?? primary;
  // Geometry from the framework-neutral specified default (RadioDefaults), read
  // here rather than hardcoded, so the web glyph and any other painted glyph
  // agree (DESIGN.md §8).
  final String size = '${px(RadioDefaults.size)}px';
  final String width = '${px(RadioDefaults.borderWidth)}px';
  return Styles(raw: <String, String>{
    'appearance': 'none',
    'width': size,
    'height': size,
    'margin': '0',
    'vertical-align': 'middle',
    'border': '$width solid ${selected ? primary : border}',
    'border-radius': '50%',
    'background-color': 'transparent',
    if (selected)
      'background-image':
          'radial-gradient(circle, $primary 0 40%, transparent 45%)',
  });
}
