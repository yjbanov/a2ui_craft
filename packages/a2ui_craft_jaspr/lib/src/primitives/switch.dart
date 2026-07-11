// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Switch` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Switch`: a bare on/off switch. Two-way bound like Checkbox. The
/// web has no stock switch element, so this control is **always**
/// adapter-painted (the one control with no native fallback): a pill track
/// with a radial-gradient thumb whose position flips with the bound value (a
/// controlled element — no pseudo-elements needed). Role mapping
/// (DESIGN.md §8): `primary` fills the active track (`onPrimary` inks the
/// thumb riding it), `outline` the inactive track; unthemed falls back to
/// the button's scheme-adaptive pair. `role=switch` gives the checkbox
/// input switch semantics (on/off from `checked`).
Component buildSwitch(BuildContext context, DataSource source) {
  ensureCoreControlStyleSheet(coreControlStyleSheet);
  final bool value = source.v<bool>(['value']) ?? false;
  final onChanged = source.handler<ValueChanged<bool>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (bool v) => trigger(<String, Object?>{'value': v}),
  );
  final String onTrack =
      roleColor(context, ThemeRoles.primary) ?? kButtonSurfaceFallback;
  final String onThumb =
      roleColor(context, ThemeRoles.onPrimary) ?? kButtonInkFallback;
  final String offTrack =
      roleColor(context, ThemeRoles.outline) ?? kSwitchOffTrackFallback;
  final String thumb = value ? onThumb : kSwitchOffThumbFallback;
  final String at = value ? '25px 10px' : '11px 10px';
  return input(
    type: InputType.checkbox,
    checked: value,
    classes: 'craft-switch',
    attributes: const <String, String>{'role': 'switch'},
    styles: Styles(raw: <String, String>{
      'appearance': 'none',
      'width': '36px',
      'height': '20px',
      'margin': '0',
      'border': 'none',
      'border-radius': '10px',
      'vertical-align': 'middle',
      'background': 'radial-gradient(circle at $at, $thumb 0 7px, '
          'transparent 8px), ${value ? onTrack : offTrack}',
    }),
    events: onChanged == null
        ? null
        : <String, EventCallback>{'change': (_) => onChanged(!value)},
  );
}
