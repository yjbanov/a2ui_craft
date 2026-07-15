// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Slider` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Slider`: a bare numeric slider (no label — that is a template's
/// choice). Two-way bound: `onChanged` is a2ui_core's setter for the bound
/// `value`.
Component buildSlider(BuildContext context, DataSource source) {
  final double min = numArg(source, 'min') ?? 0.0;
  final double max = numArg(source, 'max') ?? 1.0;
  final double value = (numArg(source, 'value') ?? min).clamp(min, max);
  final int? steps = source.v<int>(['steps']);
  // The browser delivers a range input's value as `valueAsNumber` — jaspr
  // types the event value by InputType, so the handler takes a num (a plain
  // String handler would throw a cast error on the first real drag).
  final onChanged = source.handler<ValueChanged<num>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (num v) => trigger(<String, Object?>{'value': v.toDouble()}),
  );
  ensureCoreControlStyleSheet(coreControlStyleSheet);
  return input<num>(
    type: InputType.range,
    value: '$value',
    // No `onChanged` → no value listener → the control cannot report changes,
    // so it is disabled (non-draggable, dimmed), matching the Flutter adapter
    // (`Slider(onChanged: null)` renders Material's disabled state) and the
    // handler-less `Button`. Behaviorally identical: both adapters then show
    // the value read-only rather than one accepting drags the other drops.
    disabled: onChanged == null,
    classes:
        roleColor(context, ThemeRoles.primary) == null ? null : 'craft-slider',
    styles: _sliderStyles(context,
        fraction: max > min ? (value - min) / (max - min) : 0),
    attributes: <String, String>{
      'min': '$min',
      'max': '$max',
      if (steps != null && steps > 0) 'step': '${(max - min) / steps}',
    },
    onInput: onChanged,
  );
}

/// The themed Slider track — adapter-owned painting (DESIGN.md §8).
///
/// Unthemed (no `primary`), the native UA range input is the stock look:
/// return null. Themed, `accent-color` can only tint the thumb, so the track
/// is painted from scratch: `primary` fills the active portion (a gradient
/// stop at the bound value's [fraction] — the input is controlled, so the
/// fill tracks re-renders) and inks the thumb (via the `--craft-slider-thumb`
/// custom property the control stylesheet's pseudo-element thumbs read);
/// `outline` inks the inactive track, falling back to a translucent primary.
Styles? _sliderStyles(BuildContext context, {required double fraction}) {
  final String? primary = roleColor(context, ThemeRoles.primary);
  if (primary == null) return null;
  final String track = roleColor(context, ThemeRoles.outline) ??
      'color-mix(in srgb, $primary 30%, transparent)';
  final String pct = '${numberToDisplayString(fraction.clamp(0, 1) * 100)}%';
  return Styles(raw: <String, String>{
    'appearance': 'none',
    'height': '4px',
    'border-radius': '2px',
    'background':
        'linear-gradient(to right, $primary 0%, $primary $pct, $track $pct, $track 100%)',
    '--craft-slider-thumb': primary,
  });
}
