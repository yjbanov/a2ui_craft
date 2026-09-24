// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';

/// An app-global interactive toolbar exposing the controls of [A2uiCraftSimulator].
class SimulatorToolbar extends StatelessWidget {
  const SimulatorToolbar({
    super.key,
    required this.simulator,
  });

  final A2uiCraftSimulator simulator;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MediaContext media = simulator.media;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.tune,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Simulator',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            const Text('Client: '),
            const SizedBox(width: 4),
            DropdownButton<ClientProfile>(
              value: simulator.clientProfile,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<ClientProfile>>[
                for (final ClientProfile p in ClientProfile.standardProfiles)
                  DropdownMenuItem<ClientProfile>(
                    value: p,
                    child: Text(p.label),
                  ),
              ],
              onChanged: (ClientProfile? p) {
                if (p != null) simulator.setClientProfile(p);
              },
            ),
            const SizedBox(width: 16),
            const Text('Platform: '),
            const SizedBox(width: 4),
            DropdownButton<HostPlatform>(
              value: media.platform,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<HostPlatform>>[
                for (final HostPlatform p in HostPlatform.values)
                  DropdownMenuItem<HostPlatform>(
                    value: p,
                    child: Text(p.id),
                  ),
              ],
              onChanged: (HostPlatform? p) {
                if (p != null) simulator.setPlatform(p);
              },
            ),
            const SizedBox(width: 16),
            const Text('Form: '),
            const SizedBox(width: 4),
            DropdownButton<DeviceFormFactor>(
              value: media.formFactor,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<DeviceFormFactor>>[
                for (final DeviceFormFactor f in DeviceFormFactor.values)
                  DropdownMenuItem<DeviceFormFactor>(
                    value: f,
                    child: Text(f.id),
                  ),
              ],
              onChanged: (DeviceFormFactor? f) {
                if (f != null) simulator.setFormFactor(f);
              },
            ),
            const SizedBox(width: 16),
            const Text('Theme: '),
            const SizedBox(width: 4),
            DropdownButton<SimulatorThemeMode>(
              value: simulator.themeMode,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<SimulatorThemeMode>>[
                for (final SimulatorThemeMode m in SimulatorThemeMode.values)
                  DropdownMenuItem<SimulatorThemeMode>(
                    value: m,
                    child: Text(m.id),
                  ),
              ],
              onChanged: (SimulatorThemeMode? m) {
                if (m != null) simulator.setThemeMode(m);
              },
            ),
            const SizedBox(width: 16),
            const Text('Hardware: '),
            const SizedBox(width: 6),
            for (final String cap in const <String>[
              'camera',
              'gps',
              'biometrics',
              'nfc',
            ]) ...<Widget>[
              FilterChip(
                label: Text(cap, style: const TextStyle(fontSize: 11)),
                selected: media.capabilities.contains(cap),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onSelected: (bool selected) =>
                    simulator.setCapability(cap, selected),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Reset Simulator',
              onPressed: simulator.reset,
            ),
          ],
        ),
      ),
    );
  }
}
