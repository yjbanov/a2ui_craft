// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Checkbox` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Checkbox`: a two-way bound on/off box.
Widget buildCheckbox(BuildContext context, DataSource source) {
  final bool value = source.v<bool>(['value']) ?? false;
  final ValueChanged<bool>? onChanged = source.handler<ValueChanged<bool>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (bool v) => trigger(<String, Object?>{'value': v}),
  );
  // The role mapping (DESIGN.md §8), on the Material idiom's own knobs:
  // `primary` fully fills the checked state, `onPrimary` draws the mark,
  // `outline` inks the unchecked box. Null falls through to the host
  // Material look (blend in, §9.1) — same split as the Jaspr adapter's
  // native-vs-painted glyph.
  final Color? outline = roleColor(context, ThemeRoles.outline);
  // `.adaptive`: the host-selected idiom (ThemeData.platform, DESIGN.md
  // §8) picks the Material or Cupertino rendering; CupertinoCheckbox
  // honors the same three role knobs. The native box keeps its idiom's own
  // size/corner (idiom latitude, §8); the one shared geometry knob it can honor
  // is the border width — the specified default in CheckboxDefaults.
  return Checkbox.adaptive(
    value: value,
    activeColor: roleColor(context, ThemeRoles.primary),
    checkColor: roleColor(context, ThemeRoles.onPrimary),
    side: outline == null
        ? null
        : BorderSide(color: outline, width: CheckboxDefaults.borderWidth),
    onChanged: onChanged == null ? null : (bool? v) => onChanged(v ?? !value),
  );
}
