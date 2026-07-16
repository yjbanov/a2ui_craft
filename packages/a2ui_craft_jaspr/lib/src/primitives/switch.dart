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
  // Geometry from the framework-neutral specified default (SwitchDefaults): the
  // pill radius is half the track height, and the thumb centers sit an inset +
  // radius in from each edge — read here rather than hardcoded (DESIGN.md §8).
  final double thumbRadius = SwitchDefaults.thumbDiameter / 2;
  final double cy = SwitchDefaults.trackHeight / 2;
  final double cx = value
      ? SwitchDefaults.trackWidth - SwitchDefaults.thumbInset - thumbRadius
      : SwitchDefaults.thumbInset + thumbRadius;
  return input(
    type: InputType.checkbox,
    checked: value,
    classes: 'craft-switch',
    attributes: const <String, String>{'role': 'switch'},
    styles: Styles(raw: <String, String>{
      'appearance': 'none',
      'width': '${px(SwitchDefaults.trackWidth)}px',
      'height': '${px(SwitchDefaults.trackHeight)}px',
      'margin': '0',
      'border': 'none',
      'border-radius': '${px(cy)}px',
      'vertical-align': 'middle',
      // Layer 1, the track: `primary` fill when on, `outline` when off — its own
      // `background-color`, mirroring the Checkbox's fill. Layer 3, the thumb: a
      // radial gradient `background-image` over it, mirroring the Checkbox mark.
      'background-color': value ? onTrack : offTrack,
      'background-image': 'radial-gradient(circle at ${px(cx)}px ${px(cy)}px, '
          '$thumb 0 ${px(thumbRadius)}px, transparent ${px(thumbRadius + 1)}px)',
    }),
    events: onChanged == null
        ? null
        : <String, EventCallback>{'change': (_) => onChanged(!value)},
  );
}
