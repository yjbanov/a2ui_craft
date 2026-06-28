// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `16_workout-summary` — a centered
/// `Card` with an icon `Heading` header, a `Divider`, a duration/calories/
/// distance metric `Row`, and a date caption. Numbers/dates are supplied
/// already formatted.
SampleSpec workoutSummarySpec(String framework) => SampleSpec(
      label: 'Workout',
      catalogSource: '''
import core;

widget Metric = Column(crossAxisAlignment: "center", gap: 2.0, children: [
  Text(text: args.value),
  Text(text: args.label, variant: "caption"),
]);

widget WorkoutSummary = Card(child: Column(crossAxisAlignment: "center",
  gap: 8.0, children: [
    Row(gap: 6.0, crossAxisAlignment: "center", children: [
      Icon(icon: "directions_run"),
      Heading(text: args.title, level: 3),
    ]),
    Divider(),
    Row(mainAxisAlignment: "spaceAround", width: "fill", children: [
      Metric(value: args.duration, label: "Duration"),
      Metric(value: args.calories, label: "Calories"),
      Metric(value: args.distance, label: "Distance"),
    ]),
    Text(text: args.date, variant: "caption"),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'WorkoutSummary': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'duration': <String, Object?>{r'$ref': 'DynamicString'},
              'calories': <String, Object?>{r'$ref': 'DynamicString'},
              'distance': <String, Object?>{r'$ref': 'DynamicString'},
              'date': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'WorkoutSummary',
              'title': 'Workout Complete',
              'duration': '32:15',
              'calories': '385',
              'distance': '5.2 km',
              'date': 'Monday, Dec 15 at 7:30 AM',
            },
          ],
        ),
      ],
    );
