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
  // Disabled, the box drops both roles for the surface neutral
  // (DisabledDefaults). Material already greys a handler-less box — but from
  // the *host* `ColorScheme.onSurface`, since `activeColor` and `side` only
  // describe the enabled state, so a branded surface fell back to stock
  // Material grey and could not agree with the web adapter. Null when the
  // theme omits `onSurface`, and then Material's own disabled rendering stands
  // (§9.4).
  final bool enabled = onChanged != null;
  final Color? neutral = roleColorAlpha(
      context, ThemeRoles.onSurface, DisabledDefaults.foregroundAlpha);
  final Color? boxEdge = !enabled && neutral != null ? neutral : outline;
  // `.adaptive`: the host-selected idiom (ThemeData.platform, DESIGN.md
  // §8) picks the Material or Cupertino rendering; CupertinoCheckbox
  // honors the same three role knobs. The native box keeps its idiom's own
  // size/corner (idiom latitude, §8); the one shared geometry knob it can honor
  // is the border width — the specified default in CheckboxDefaults.
  return Checkbox.adaptive(
    value: value,
    activeColor: roleColor(context, ThemeRoles.primary),
    // Whichever state we are in — `checkColor` is not state-resolved, but the
    // handler tells us the state at build time. On the dimmed fill the mark
    // rides `color.surface`, as Material's disabled mark does.
    checkColor: enabled
        ? roleColor(context, ThemeRoles.onPrimary)
        : roleColor(context, ThemeRoles.surface),
    // The checked fill has to come through `fillColor`: Material deliberately
    // drops `activeColor` in the disabled state (`_widgetFillColor` returns
    // null there), so it is the only per-widget knob that reaches it. Null for
    // every other state, falling through to `activeColor` and the defaults.
    fillColor: neutral == null
        ? null
        : WidgetStateProperty.resolveWith((Set<WidgetState> states) =>
            states.contains(WidgetState.disabled) &&
                    states.contains(WidgetState.selected)
                ? neutral
                : null),
    side: boxEdge == null
        ? null
        : BorderSide(color: boxEdge, width: CheckboxDefaults.borderWidth),
    onChanged: onChanged == null ? null : (bool? v) => onChanged(v ?? !value),
  );
}
