// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `28_countdown-timer` — a centered
/// `Card` with a `Heading` event name, a days/hours/minutes `Row`, and a target
/// date (supplied already formatted).
SampleSpec countdownTimerSpec(String framework) => SampleSpec(
      label: 'Countdown',
      catalogSource: '''
import core;

widget Unit = Column(crossAxisAlignment: "center", gap: 2.0, children: [
  Text(text: args.value),
  Text(text: args.label, variant: "caption"),
]);

widget CountdownTimer = Card(child: Column(crossAxisAlignment: "center",
  gap: 8.0, children: [
    Heading(text: args.eventName, level: 2),
    Row(mainAxisAlignment: "spaceAround", width: "fill", children: [
      Unit(value: args.days, label: "Days"),
      Unit(value: args.hours, label: "Hours"),
      Unit(value: args.minutes, label: "Minutes"),
    ]),
    Text(text: args.targetDate),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Unit': <String, Object?>{
            'properties': <String, Object?>{
              'value': <String, Object?>{r'$ref': 'DynamicString'},
              'label': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
          'CountdownTimer': <String, Object?>{
            'properties': <String, Object?>{
              'eventName': <String, Object?>{r'$ref': 'DynamicString'},
              'days': <String, Object?>{r'$ref': 'DynamicString'},
              'hours': <String, Object?>{r'$ref': 'DynamicString'},
              'minutes': <String, Object?>{r'$ref': 'DynamicString'},
              'targetDate': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'CountdownTimer',
              'eventName': 'Product Launch',
              'days': '14',
              'hours': '08',
              'minutes': '32',
              'targetDate': 'January 15, 2025',
            },
          ],
        ),
      ],
    );
