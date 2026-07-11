// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Select` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `Select`: a single-choice dropdown over string `options` — the bare
/// control; label placement is a template's choice, like TextField. Two-way
/// bound: `onChanged` is a2ui_core's setter for the bound `value`. Shares the
/// TextField chrome (`outline`/`primary`) and ink (`onSurface`).
Widget buildSelect(BuildContext context, DataSource source) {
  final List<String> options = stringList(source, 'options');
  final String? value = source.v<String>(['value']);
  final ValueChanged<String>? onChanged = source.handler<ValueChanged<String>>(
    ['onChanged'],
    (HandlerTrigger trigger) =>
        (String v) => trigger(<String, Object?>{'value': v}),
  );
  final Color? ink = roleColor(context, ThemeRoles.onSurface);
  // Hug the content, like the web's native <select> (and unlike
  // Material's fill-the-parent InputDecorator, which also rejects the
  // unbounded width a hug-sized Row hands its children).
  return IntrinsicWidth(
      child: DropdownButtonFormField<String>(
    // An unknown/absent value renders no selection rather than throwing.
    initialValue: options.contains(value) ? value : null,
    decoration: fieldDecoration(context),
    style: ink == null ? null : TextStyle(color: ink),
    items: <DropdownMenuItem<String>>[
      for (final String option in options)
        DropdownMenuItem<String>(value: option, child: Text(option)),
    ],
    onChanged: onChanged == null
        ? null
        : (String? v) {
            if (v != null) onChanged(v);
          },
  ));
}
