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
  final Slider slider = Slider.adaptive(
    min: min,
    max: max,
    value: value,
    activeColor: roleColor(context, ThemeRoles.primary),
    inactiveColor: roleColor(context, ThemeRoles.outline),
    divisions: (steps != null && steps > 0) ? steps : null,
    onChanged: onChanged,
  );
  return _themedDisabled(context, slider);
}

/// Re-points Material's disabled slider colors at the project theme.
///
/// Material already greys a handler-less slider — but from the *host*
/// `ColorScheme.onSurface`, ignoring the project theme, because `activeColor`
/// and `inactiveColor` only describe the enabled state. A branded surface
/// therefore fell back to stock Material grey, and the web adapter (which
/// derives the same state from the theme) could not agree with it. Reading
/// `color.onSurface` here puts both adapters on one neutral.
///
/// Untouched when the theme omits `onSurface` — including every unthemed
/// surface, where Material's own disabled rendering is exactly the host blend
/// the contract promises (§9.4).
Widget _themedDisabled(BuildContext context, Slider slider) {
  final Color? active = roleColorAlpha(
      context, ThemeRoles.onSurface, DisabledDefaults.foregroundAlpha);
  if (active == null) return slider;
  final Color inactive = roleColorAlpha(
      context, ThemeRoles.onSurface, DisabledDefaults.backgroundAlpha)!;
  return SliderTheme(
    data: SliderTheme.of(context).copyWith(
      disabledActiveTrackColor: active,
      disabledThumbColor: active,
      disabledInactiveTrackColor: inactive,
    ),
    child: slider,
  );
}
