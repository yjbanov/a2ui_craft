// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `TextField` primitive.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'support.dart';

/// Builds `TextField`: the bare text input — no label. Label placement is a
/// template's choice (see DESIGN.md §4 "Bias to templatize" / §8), composed as
/// a separate Text.
Widget buildTextField(BuildContext context, DataSource source) {
  return _CoreTextField(
    value: source.v<String>(['value']),
    outline: roleColor(context, ThemeRoles.outline),
    accent: roleColor(context, ThemeRoles.primary),
    ink: roleColor(context, ThemeRoles.onSurface),
    // The `onChanged` arg is a2ui_core's two-way setter (a resolved
    // callback), accepted directly by the runtime's handler affordance.
    onChanged: source.handler<ValueChanged<String>>(
      ['onChanged'],
      (HandlerTrigger trigger) =>
          (String value) => trigger(<String, Object?>{'value': value}),
    ),
  );
}

/// A text field that reflects an externally-bound [value] (without clobbering
/// the cursor mid-edit) and reports edits through [onChanged] — the two halves
/// of two-way binding.
class _CoreTextField extends StatefulWidget {
  const _CoreTextField(
      {this.value, this.onChanged, this.outline, this.accent, this.ink});

  final String? value;
  final ValueChanged<String>? onChanged;

  /// The `color.outline` role — the field's chrome (a 1px box border, the
  /// stock 6px control corner, 8/12 content padding); null keeps the host's
  /// default decoration (blend in, §9.1). Error states keep the host
  /// emphasis until the contract grows state roles.
  final Color? outline;

  /// The `color.primary` role — the focused border and the caret; null keeps
  /// the host emphasis.
  final Color? accent;

  /// The `color.onSurface` role — the typed text's ink; null inherits.
  final Color? ink;

  @override
  State<_CoreTextField> createState() => _CoreTextFieldState();
}

class _CoreTextFieldState extends State<_CoreTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(_CoreTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect external (data-model) changes, but don't fight the user's cursor
    // for edits that already match.
    if (widget.value != null && widget.value != _controller.text) {
      _controller.text = widget.value!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: widget.ink == null ? null : TextStyle(color: widget.ink),
      cursorColor: widget.accent,
      decoration: fieldDecorationFor(widget.outline, widget.accent),
      onChanged: widget.onChanged,
    );
  }
}
