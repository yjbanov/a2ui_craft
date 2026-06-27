// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// A `Boxes` widget that shows the `Box` primitive: nested boxes exercising
/// explicit sizing, padding, margin, a background color, and `fill`.
SampleSpec boxesSpec(String framework) => SampleSpec(
      label: 'Boxes',
      catalogSource: '''
import core;

widget Boxes = Column(gap: 20, children: [
  Text(text: "Here are some nested boxes with margins and padding:"),
  Box(
    padding: [20.0, 20.0, 20.0, 20.0],
    color: "#e2e8f0",
    child: Box(
      width: 100.0,
      height: 100.0,
      color: "#94a3b8",
      child: Box(
        margin: [10.0, 10.0, 10.0, 10.0],
        width: "fill",
        height: "fill",
        color: "#334155",
        child: Center(
          child: Text(text: "Center")
        )
      )
    )
  ),
  Box(
    margin: [20.0, 0.0, 0.0, 0.0],
    padding: [10.0, 10.0, 10.0, 10.0],
    color: "#cbd5e1",
    child: Row(gap: 10, children: [
      Box(width: 50.0, height: 50.0, color: "#ef4444"),
      Box(width: 50.0, height: 50.0, color: "#10b981"),
      Box(width: 50.0, height: 50.0, color: "#3b82f6"),
    ])
  )
]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Boxes': <String, Object?>{
            'properties': <String, Object?>{},
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'root', 'component': 'Boxes'},
          ],
        ),
      ],
    );
