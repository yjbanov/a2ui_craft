// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// An app-global interactive toolbar exposing the controls of [A2uiCraftSimulator].
class SimulatorToolbar extends StatelessComponent {
  const SimulatorToolbar({
    required this.simulator,
    super.key,
  });

  final A2uiCraftSimulator simulator;

  @override
  Component build(BuildContext context) {
    final MediaContext media = simulator.media;

    return div(
      styles: Styles(
        raw: <String, String>{
          'display': 'flex',
          'flex-direction': 'row',
          'align-items': 'center',
          'gap': '12px',
          'padding': '8px 16px',
          'background-color': '#F1F5F9',
          'border-bottom': '1px solid #CBD5E1',
          'font-size': '13px',
          'overflow-x': 'auto',
          'white-space': 'nowrap',
          'box-sizing': 'border-box',
          'width': '100%',
        },
      ),
      <Component>[
        span(
          styles: Styles(
            raw: <String, String>{
              'font-weight': 'bold',
              'color': '#2563EB',
            },
          ),
          <Component>[Component.text('Simulator')],
        ),

        // Client Profile
        span(<Component>[Component.text('Client: ')]),
        select(
          onChange: (List<String> values) {
            if (values.isNotEmpty) {
              final String id = values.first;
              for (final ClientProfile p in ClientProfile.standardProfiles) {
                if (p.id == id) {
                  simulator.setClientProfile(p);
                  break;
                }
              }
            }
          },
          <Component>[
            for (final ClientProfile p in ClientProfile.standardProfiles)
              option(
                value: p.id,
                selected: p.id == simulator.clientProfile.id,
                <Component>[Component.text(p.label)],
              ),
          ],
        ),

        // Platform
        span(<Component>[Component.text('Platform: ')]),
        select(
          onChange: (List<String> values) {
            if (values.isNotEmpty) {
              final String id = values.first;
              for (final HostPlatform p in HostPlatform.values) {
                if (p.id == id) {
                  simulator.setPlatform(p);
                  break;
                }
              }
            }
          },
          <Component>[
            for (final HostPlatform p in HostPlatform.values)
              option(
                value: p.id,
                selected: p == media.platform,
                <Component>[Component.text(p.id)],
              ),
          ],
        ),

        // Form Factor
        span(<Component>[Component.text('Form: ')]),
        select(
          onChange: (List<String> values) {
            if (values.isNotEmpty) {
              final String id = values.first;
              for (final DeviceFormFactor f in DeviceFormFactor.values) {
                if (f.id == id) {
                  simulator.setFormFactor(f);
                  break;
                }
              }
            }
          },
          <Component>[
            for (final DeviceFormFactor f in DeviceFormFactor.values)
              option(
                value: f.id,
                selected: f == media.formFactor,
                <Component>[Component.text(f.id)],
              ),
          ],
        ),

        // Theme Mode
        span(<Component>[Component.text('Theme: ')]),
        select(
          onChange: (List<String> values) {
            if (values.isNotEmpty) {
              final String id = values.first;
              for (final SimulatorThemeMode m in SimulatorThemeMode.values) {
                if (m.id == id) {
                  simulator.setThemeMode(m);
                  break;
                }
              }
            }
          },
          <Component>[
            for (final SimulatorThemeMode m in SimulatorThemeMode.values)
              option(
                value: m.id,
                selected: m == simulator.themeMode,
                <Component>[Component.text(m.id)],
              ),
          ],
        ),

        // Hardware Capabilities
        span(<Component>[Component.text('Hardware: ')]),
        for (final String cap in const <String>[
          'camera',
          'gps',
          'biometrics',
          'nfc',
        ]) ...<Component>[
          button(
            type: ButtonType.button,
            onClick: () => simulator.toggleCapability(cap),
            styles: Styles(
              raw: <String, String>{
                'padding': '2px 8px',
                'border-radius': '12px',
                'border': '1px solid #94A3B8',
                'font-size': '11px',
                'cursor': 'pointer',
                'background-color':
                    media.capabilities.contains(cap) ? '#3B82F6' : '#FFFFFF',
                'color':
                    media.capabilities.contains(cap) ? '#FFFFFF' : '#1E293B',
              },
            ),
            <Component>[Component.text(cap)],
          ),
        ],

        // Reset
        button(
          type: ButtonType.button,
          onClick: simulator.reset,
          styles: Styles(
            raw: <String, String>{
              'margin-left': '8px',
              'padding': '4px 10px',
              'border-radius': '4px',
              'border': '1px solid #CBD5E1',
              'background-color': '#FFFFFF',
              'cursor': 'pointer',
              'font-size': '12px',
            },
          ),
          <Component>[Component.text('Reset')],
        ),
      ],
    );
  }
}
