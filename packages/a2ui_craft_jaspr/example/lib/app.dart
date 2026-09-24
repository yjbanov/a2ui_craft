// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'sample.dart';
import 'simulator_toolbar.dart';
import 'system_dark.dart';

/// The shared sample specs.
final List<SampleSpec> _specs = sampleSpecs();

/// A simple gallery shell that shows one [Sample] at a time. Each sample is
/// fully self-contained, so switching tabs tears the old one down and builds the
/// next from scratch.
class App extends StatefulComponent {
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _index = 0;
  final A2uiCraftSimulator _simulator = A2uiCraftSimulator();

  // The system dark-light preference; themed samples open in the matching
  // mode and re-theme when it flips (host render-time config, DESIGN.md §9.5).
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _dark = systemPrefersDark();
    watchSystemDark((bool dark) => setState(() => _dark = dark));
    _simulator.addListener(_onSimulatorChanged);
  }

  void _onSimulatorChanged() => setState(() {});

  @override
  void dispose() {
    _simulator.removeListener(_onSimulatorChanged);
    _simulator.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        height: Unit.vh(100),
      ),
      <Component>[
        SimulatorToolbar(simulator: _simulator),
        div(
          styles: Styles(
            display: Display.flex,
            flexDirection: FlexDirection.row,
            flex: Flex(grow: 1),
            overflow: Overflow.hidden,
          ),
          <Component>[
            div(
              styles: Styles(
                display: Display.flex,
                flexDirection: FlexDirection.column,
                width: Unit.pixels(200),
                padding: Padding.all(Unit.pixels(20)),
                border: Border.all(color: Colors.blue, width: Unit.pixels(1)),
                // Scroll the nav when the sample list exceeds the viewport height.
                overflow: Overflow.auto,
              ),
              <Component>[
                for (var i = 0; i < _specs.length; i++) ...<Component>[
                  button(
                    onClick: () => setState(() => _index = i),
                    <Component>[Component.text(_specs[i].label)],
                  ),
                  div(
                      styles: Styles(height: Unit.pixels(10)),
                      const <Component>[]),
                ],
              ],
            ),
            div(
              styles: Styles(
                flex: Flex(grow: 1),
                display: Display.flex,
                justifyContent: JustifyContent.center,
                alignItems: AlignItems.center,
                overflow: Overflow.auto,
              ),
              <Component>[
                div(
                  styles: Styles(
                    padding: Padding.all(Unit.pixels(20)),
                    border:
                        Border.all(color: Colors.blue, width: Unit.pixels(2)),
                    radius: BorderRadius.circular(Unit.pixels(8)),
                  ),
                  // The key ensures a fresh, isolated sample on every switch.
                  <Component>[
                    Sample(
                      _specs[_index],
                      dark: _dark,
                      simulator: _simulator,
                      key: ValueKey<int>(_index),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
