// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';

/// Renders a [SampleSpec] with the Flutter adapter — a thin wrapper over the
/// reusable [SampleView].
///
/// A themed project opens in the mode matching the platform's dark-light
/// setting (host render-time config, DESIGN.md §9.5) and re-themes when it
/// flips — `MediaQuery.platformBrightnessOf` subscribes this widget to
/// brightness changes. When [simulator] is provided, theme brightness and
/// responsive media are resolved from the simulator.
class Sample extends StatelessWidget {
  const Sample(this.spec, {this.simulator, super.key});

  final SampleSpec spec;
  final A2uiCraftSimulator? simulator;

  @override
  Widget build(BuildContext context) {
    final ProjectTheme? theme = spec.theme;
    final bool systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bool dark = simulator?.isDark(systemDark) ?? systemDark;
    return SampleView(
      template: spec.catalogSource,
      schema: spec.catalogSchema,
      messages: spec.messages,
      theme: theme?.resolve(theme.modeFor(dark: dark)),
      simulator: simulator,
    );
  }
}
