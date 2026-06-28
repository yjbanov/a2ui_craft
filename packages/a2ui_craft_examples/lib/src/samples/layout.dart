// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// A `LayoutDemo` widget showcasing the layout-depth primitives beyond the
/// Flex/Box slices — `Align`, `AspectRatio`, `Wrap`, and `Opacity` — each
/// rendered identically by the Flutter and Jaspr adapters.
SampleSpec layoutSpec(String framework) => SampleSpec(
      label: 'Layout',
      catalogSource: '''
import core;

widget LayoutDemo = Column(gap: 12, children: [
  Text(text: "Layout primitives (same on every adapter):"),

  Text(text: "Align — anchored bottom-right in a fixed box:", variant: "caption"),
  Box(width: 200.0, height: 60.0, color: "#e2e8f0",
    child: Align(alignment: "bottomRight", width: 200.0, height: 60.0,
      child: Box(width: 40.0, height: 30.0, color: "#3b82f6"))),

  Text(text: "AspectRatio — height derived from width (2.5:1):", variant: "caption"),
  SizedBox(width: 200.0,
    child: AspectRatio(ratio: 2.5,
      child: Box(width: "fill", height: "fill", color: "#10b981"))),

  Text(text: "Wrap — chips flow and wrap to the next run:", variant: "caption"),
  SizedBox(width: 260.0,
    child: Wrap(gap: 8.0, runGap: 8.0, children: [
      Box(width: 70.0, height: 30.0, color: "#fca5a5"),
      Box(width: 70.0, height: 30.0, color: "#fcd34d"),
      Box(width: 70.0, height: 30.0, color: "#86efac"),
      Box(width: 70.0, height: 30.0, color: "#93c5fd"),
    ])),

  Text(text: "Opacity — child faded to 35%:", variant: "caption"),
  Opacity(opacity: 0.35,
    child: Box(width: 140.0, height: 36.0, color: "#7c3aed",
      child: Center(child: Text(text: "faded")))),
]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'LayoutDemo': <String, Object?>{
            'properties': <String, Object?>{},
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'root', 'component': 'LayoutDemo'},
          ],
        ),
      ],
    );
