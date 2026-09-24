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
/// When [simulator] is provided, theme brightness and responsive media are
/// resolved from the simulator.
class Sample extends StatelessComponent {
  const Sample(
    this.spec, {
    this.dark = false,
    this.simulator,
    super.key,
  });

  final SampleSpec spec;

  /// Whether the host prefers dark mode.
  final bool dark;

  /// The interactive simulator controller, or null for the real host environment.
  final A2uiCraftSimulator? simulator;

  @override
  Component build(BuildContext context) {
    final ProjectTheme? theme = spec.theme;
    final bool resolvedDark = simulator?.isDark(dark) ?? dark;
    return SampleView(
      template: spec.catalogSource,
      schema: spec.catalogSchema,
      messages: spec.messages,
      theme: theme?.resolve(theme.modeFor(dark: resolvedDark)),
      simulator: simulator,
    );
  }
}
