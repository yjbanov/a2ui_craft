// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// A `StatsCard` catalog widget, modeled on the gallery's activity/stats
/// cards: a titled `Card` with a `Divider`, a `Row` of stat `Column`s
/// (value + caption), and a `Slider` showing progress toward a goal. Exercises
/// the atoms (`Text` variants, `Icon`, `Divider`) plus the new `Slider`
/// primitive in a real surface.
///
/// A fixed-width `Box` bounds the card so the `fill`-width / `spaceBetween` rows
/// have a definite extent to distribute within.
SampleSpec statsCardSpec(String framework) => SampleSpec(
      label: 'Stats Card',
      catalogSource: '''
import core;

widget Stat = Column(crossAxisAlignment: "center", children: [
  Text(text: args.value),
  Text(text: args.label, variant: "caption"),
]);

widget StatsCard = Box(width: 300.0, child: Card(child: Column(gap: 12.0, children: [
  Row(mainAxisAlignment: "spaceBetween", width: "fill", children: [
    Text(text: args.title),
    Icon(icon: "favorite"),
  ]),
  Divider(),
  Row(mainAxisAlignment: "spaceAround", width: "fill", children: [
    Stat(value: args.steps, label: "steps"),
    Stat(value: args.calories, label: "kcal"),
    Stat(value: args.minutes, label: "min"),
  ]),
  Text(text: "Daily goal: 70%", variant: "caption"),
  Slider(value: 70.0, min: 0.0, max: 100.0),
])));
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
          'StatsCard': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'steps': <String, Object?>{r'$ref': 'DynamicString'},
              'calories': <String, Object?>{r'$ref': 'DynamicString'},
              'minutes': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'StatsCard',
              'title': "Today's Activity",
              'steps': '8,420',
              'calories': '612',
              'minutes': '47',
            },
          ],
        ),
      ],
    );
