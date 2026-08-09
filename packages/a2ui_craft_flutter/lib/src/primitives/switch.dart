// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Switch` primitive.
library;

// The template-language model's `Switch` (the RFW switch expression) is not
// used here and would shadow Material's `Switch` control.
import 'package:a2ui_craft/a2ui_craft.dart' hide Switch;
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Switch`: a bare on/off switch. Two-way bound like Checkbox; the
/// role mapping (DESIGN.md §8): `primary` fully fills the active track
/// (`onPrimary` inks the thumb riding it), `outline` fills the **inactive
/// track** — the same part the web glyph inks, so a role inks one part on every
/// adapter. The inactive thumb is a contrasting neutral (surface), not a role,
/// matching the web glyph's light thumb. Null roles keep the host Material look
/// (blend in, §9.1).
Widget buildSwitch(BuildContext context, DataSource source) {
  final bool value = source.v<bool>(['value']) ?? false;
  final ValueChanged<bool>? onChanged = source.handler<ValueChanged<bool>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (bool v) => trigger(<String, Object?>{'value': v}),
  );
  final Color? outline = roleColor(context, ThemeRoles.outline);
  // Disabled, both positions collapse to one pair from the surface neutral
  // (DisabledDefaults): a faint track under a stronger thumb. The switch keeps
  // saying which way it is set — the thumb still travels — while saying it
  // cannot be moved. Material's own disabled colors read the *host* scheme, so
  // as with the Slider a branded surface needed these stated to agree with the
  // web glyph. Null when the theme omits `onSurface` (§9.4).
  final Color? neutral = roleColorAlpha(
      context, ThemeRoles.onSurface, DisabledDefaults.foregroundAlpha);
  final Color? neutralTrack = roleColorAlpha(
      context, ThemeRoles.onSurface, DisabledDefaults.backgroundAlpha);
  final bool dim = onChanged == null && neutral != null;
  // Material routes both track knobs through the disabled state, and takes the
  // *inactive* thumb color for it whichever way the switch is set — so setting
  // the pair to the neutral covers all four disabled combinations.
  // `.adaptive`: under the Cupertino idiom the switch takes the iOS look
  // while honoring the same knobs (Flutter's adaptive switch is a
  // Material implementation that restyles itself).
  return Switch.adaptive(
    value: value,
    activeTrackColor:
        dim ? neutralTrack : roleColor(context, ThemeRoles.primary),
    activeThumbColor: dim ? neutral : roleColor(context, ThemeRoles.onPrimary),
    // `outline` inks the inactive track *fill* (§8: the same part as the web
    // glyph). The off-thumb rides it as a contrasting neutral, not a role.
    inactiveTrackColor: dim ? neutralTrack : outline,
    inactiveThumbColor: dim
        ? neutral
        : (outline == null ? null : Theme.of(context).colorScheme.surface),
    onChanged: onChanged,
  );
}
