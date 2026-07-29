// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The site's **segmented control** — a row of mutually exclusive options with
/// the active one filled.
///
/// The counterpart to [CraftMenu]: a segment costs horizontal space but no
/// taps, so it earns its place only for a short axis you flip *constantly*. On
/// this site that is exactly one thing — the Jaspr/Flutter adapter switch,
/// which is the whole point of both the sample screens and `/primitives`.
/// Everything more occasional (brand, mode, size class) is a menu.
///
/// Two loose buttons say the same thing far less well: they read as two
/// independent actions, and "Jaspr is on" has to be inferred from the fill
/// rather than from the control's shape. One bordered group with a shared
/// outline is unmistakably *one* choice with two positions.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class CraftSegmented extends StatelessComponent {
  const CraftSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.ariaLabel,
    this.className,
  });

  /// The segment labels, in display order.
  final List<String> options;

  /// The active option — matched against [options] by value.
  final String selected;

  final void Function(String option) onSelect;

  /// The group's accessible name (the segments carry the individual ones).
  final String ariaLabel;

  /// An extra class on the group root — how a toolbar marks the control
  /// `wide-only`, since the visibility rule has to land on the same element
  /// that carries `display: inline-flex`.
  final String? className;

  @override
  Component build(BuildContext context) {
    return div(
      classes: className == null ? 'segmented' : 'segmented $className',
      // A radiogroup, not a plain group: the segments are `role="radio"`, and
      // a radio outside a radiogroup has no owner to report "1 of 2" from.
      attributes: <String, String>{
        'role': 'radiogroup',
        'aria-label': ariaLabel,
      },
      <Component>[
        for (final String option in options)
          button(
            classes: 'segmented-item',
            onClick: () {
              if (option == selected) return;
              onSelect(option);
            },
            attributes: <String, String>{
              'role': 'radio',
              'aria-checked': '${option == selected}',
            },
            [Component.text(option)],
          ),
      ],
    );
  }
}
