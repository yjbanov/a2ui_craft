// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `04_weather-current` — a `Card` with
/// the current temperature, location, and a `...for` row of forecast days.
///
/// The spec computes display strings with `formatString`/`formatDate`; a
/// template renders strings, so the formatted values (e.g. `72°`, weekday
/// names) are supplied directly in the data — formatting is the agent's job.
SampleSpec weatherSpec(String framework) => SampleSpec(
      label: 'Weather',
      catalogSource: '''
import core;

widget Weather = Card(child: Column(crossAxisAlignment: "center", gap: 6.0,
  children: [
    Row(gap: 8.0, children: [
      Text(text: args.tempHigh),
      Text(text: args.tempLow, variant: "caption"),
    ]),
    Text(text: args.location),
    Text(text: args.description, variant: "caption"),
    Row(mainAxisAlignment: "spaceAround", width: "fill", gap: 12.0, children: [
      ...for day in args.forecast: Column(crossAxisAlignment: "center",
        gap: 2.0, children: [
          Text(text: day.name, variant: "caption"),
          Text(text: day.icon),
          Text(text: day.temp, variant: "caption"),
        ]),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Weather': <String, Object?>{
            'properties': <String, Object?>{
              'tempHigh': <String, Object?>{r'$ref': 'DynamicString'},
              'tempLow': <String, Object?>{r'$ref': 'DynamicString'},
              'location': <String, Object?>{r'$ref': 'DynamicString'},
              'description': <String, Object?>{r'$ref': 'DynamicString'},
              'forecast': <String, Object?>{
                'type': 'array',
                'items': <String, Object?>{'type': 'object'},
              },
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
              'component': 'Weather',
              'tempHigh': '72°',
              'tempLow': '58°',
              'location': 'Austin, TX',
              'description': 'Clear skies with light breeze',
              'forecast': <Object?>[
                <String, Object?>{'name': 'Mon', 'icon': '☀', 'temp': '74°'},
                <String, Object?>{'name': 'Tue', 'icon': '☀', 'temp': '76°'},
                <String, Object?>{'name': 'Wed', 'icon': '⛅', 'temp': '71°'},
                <String, Object?>{'name': 'Thu', 'icon': '☀', 'temp': '73°'},
                <String, Object?>{'name': 'Fri', 'icon': '☀', 'temp': '75°'},
              ],
            },
          ],
        ),
      ],
    );
