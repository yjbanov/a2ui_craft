// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Slider` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Slider`: a bare numeric slider (no label — that is a template's
/// choice). Two-way bound: `onChanged` is a2ui_core's setter for the bound
/// `value`.
Widget buildSlider(BuildContext context, DataSource source) {
  final double min = numArg(source, 'min') ?? 0.0;
  final double max = numArg(source, 'max') ?? 1.0;
  final double value = (numArg(source, 'value') ?? min).clamp(min, max);
  final int? steps = source.v<int>(['steps']);
  final ValueChanged<double>? onChanged = source.handler<ValueChanged<double>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (double v) => trigger(<String, Object?>{'value': v}),
  );
  // The role mapping (DESIGN.md §8): `primary` inks the active track and
  // the thumb (Material's thumbColor follows activeColor), `outline` the
  // inactive track; null keeps the host look. `.adaptive`: under the
  // Cupertino idiom this renders a real CupertinoSlider, which has no
  // inactive-track knob — a per-idiom limit: `outline` is ignored there,
  // never repurposed.
  return Slider.adaptive(
    min: min,
    max: max,
    value: value,
    activeColor: roleColor(context, ThemeRoles.primary),
    inactiveColor: roleColor(context, ThemeRoles.outline),
    divisions: (steps != null && steps > 0) ? steps : null,
    onChanged: onChanged,
  );
}
