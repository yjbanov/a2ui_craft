// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `23_step-counter` — a centered `Card`
/// with an icon `Heading` header, a large step count, a goal caption, a
/// `Divider`, and a distance/calories stat `Row`. Numbers are supplied already
/// formatted (the spec uses `formatNumber`/`formatString`).
SampleSpec stepCounterSpec(String framework) => SampleSpec(
      label: 'Step Counter',
      catalogSource: '''
import core;

widget Stat = Column(crossAxisAlignment: "center", gap: 2.0, children: [
  Text(text: args.value),
  Text(text: args.label, variant: "caption"),
]);

widget StepCounter = Card(child: Column(crossAxisAlignment: "center", gap: 8.0,
  children: [
    Row(gap: 6.0, crossAxisAlignment: "center", children: [
      Icon(icon: "person"),
      Heading(text: args.title, level: 3),
    ]),
    Text(text: args.steps),
    Text(text: args.goal, variant: "body"),
    Divider(),
    Row(mainAxisAlignment: "spaceAround", width: "fill", children: [
      Stat(value: args.distance, label: "Distance"),
      Stat(value: args.calories, label: "Calories"),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Stat': <String, Object?>{
            'properties': <String, Object?>{
              'value': <String, Object?>{r'$ref': 'DynamicString'},
              'label': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
          'StepCounter': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'steps': <String, Object?>{r'$ref': 'DynamicString'},
              'goal': <String, Object?>{r'$ref': 'DynamicString'},
              'distance': <String, Object?>{r'$ref': 'DynamicString'},
              'calories': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'StepCounter',
              'title': "Today's Steps",
              'steps': '8,432',
              'goal': '84% of 10,000 goal',
              'distance': '3.8 mi',
              'calories': '312',
            },
          ],
        ),
      ],
    );
