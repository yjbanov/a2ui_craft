// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Radio` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Radio`: a single radio button that shows `selected` and fires
/// `onChanged` when tapped ("select me"). Grouping — which radio is on — is
/// the template's job.
// TODO(a2ui-craft): revisit. This renders a tappable radio glyph rather than
// the material `Radio<T>` widget, whose `groupValue`/`onChanged` API is
// mid-deprecation in Flutter 3.46. Move to `RadioGroup`/`Radio` once that
// settles, and reconcile the "select-me" event with the native group model.
Widget buildRadio(BuildContext context, DataSource source) {
  final bool selected = source.v<bool>(['selected']) ?? false;
  final VoidCallback? onChanged = source.voidHandler(['onChanged']);
  return _CoreRadio(
    selected: selected,
    onChanged: onChanged,
    // The role mapping (DESIGN.md §8): `primary` inks the selected glyph,
    // `outline` rings the unselected one; null keeps the host look.
    accent: roleColor(context, ThemeRoles.primary),
    outline: roleColor(context, ThemeRoles.outline),
  );
}

/// The radio glyph behind the `Radio` primitive, with the semantics the bare
/// `GestureDetector` + `Icon` lacked: a checked/unchecked state in a mutually
/// exclusive group, enabled/disabled, focus, and keyboard activation — parity
/// with the Jaspr adapter's native `<input type=radio>`. (The glyph itself is
/// still the interim rendering; see the TODO at [buildRadio].)
class _CoreRadio extends StatelessWidget {
  const _CoreRadio({
    required this.selected,
    required this.onChanged,
    this.accent,
    this.outline,
  });

  final bool selected;
  final VoidCallback? onChanged;

  /// The `color.primary` role, shown by the selected glyph; null keeps the
  /// host look.
  final Color? accent;

  /// The `color.outline` role, ringing the unselected glyph; null keeps the
  /// host look.
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        enabled: enabled,
        child: FocusableActionDetector(
          enabled: enabled,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                onChanged!();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (ButtonActivateIntent intent) {
                onChanged!();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: onChanged,
            child: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accent : outline,
            ),
          ),
        ),
      ),
    );
  }
}
