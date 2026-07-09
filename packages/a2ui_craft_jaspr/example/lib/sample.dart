// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';

/// Renders a [SampleSpec] with the Jaspr adapter — a thin wrapper over the
/// reusable [SampleView].
///
/// A themed project opens in the mode matching [dark] — the host's system
/// dark-light preference (render-time config, DESIGN.md §9.5), supplied by
/// the gallery shell. Unthemed samples ignore it and blend into the host.
class Sample extends StatelessComponent {
  const Sample(this.spec, {this.dark = false, super.key});

  final SampleSpec spec;

  /// Whether the host prefers dark mode.
  final bool dark;

  @override
  Component build(BuildContext context) {
    final ProjectTheme? theme = spec.theme;
    return SampleView(
      template: spec.catalogSource,
      schema: spec.catalogSchema,
      messages: spec.messages,
      theme: theme?.resolve(theme.modeFor(dark: dark)),
    );
  }
}
