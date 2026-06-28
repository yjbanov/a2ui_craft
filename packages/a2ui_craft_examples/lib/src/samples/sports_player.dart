// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `14_sports-player` — a centered `Card`
/// with the player image, a `Heading` name + number/team `Row`, a `Divider`, and
/// a three-stat `Row`. Image is an `example.com` placeholder.
SampleSpec sportsPlayerSpec(String framework) => SampleSpec(
      label: 'Sports Player',
      catalogSource: '''
import core;

widget Stat = Column(crossAxisAlignment: "center", gap: 2.0, children: [
  Text(text: args.value),
  Text(text: args.label, variant: "caption"),
]);

widget SportsPlayer = Card(child: Column(crossAxisAlignment: "center", gap: 8.0,
  children: [
    Image(url: args.image, variant: "avatar", fit: "cover"),
    Column(crossAxisAlignment: "center", gap: 2.0, children: [
      Heading(text: args.name, level: 2),
      Row(gap: 8.0, crossAxisAlignment: "center", children: [
        Text(text: args.number),
        Text(text: args.team, variant: "caption"),
      ]),
    ]),
    Divider(),
    Row(mainAxisAlignment: "spaceAround", width: "fill", children: [
      Stat(value: args.stat1Value, label: args.stat1Label),
      Stat(value: args.stat2Value, label: args.stat2Label),
      Stat(value: args.stat3Value, label: args.stat3Label),
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
          'SportsPlayer': <String, Object?>{
            'properties': <String, Object?>{
              'image': <String, Object?>{r'$ref': 'DynamicString'},
              'name': <String, Object?>{r'$ref': 'DynamicString'},
              'number': <String, Object?>{r'$ref': 'DynamicString'},
              'team': <String, Object?>{r'$ref': 'DynamicString'},
              'stat1Value': <String, Object?>{r'$ref': 'DynamicString'},
              'stat1Label': <String, Object?>{r'$ref': 'DynamicString'},
              'stat2Value': <String, Object?>{r'$ref': 'DynamicString'},
              'stat2Label': <String, Object?>{r'$ref': 'DynamicString'},
              'stat3Value': <String, Object?>{r'$ref': 'DynamicString'},
              'stat3Label': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'SportsPlayer',
              'image': 'https://example.com/player.jpg',
              'name': 'Marcus Johnson',
              'number': '#23',
              'team': 'LA Lakers',
              'stat1Value': '28.4',
              'stat1Label': 'PPG',
              'stat2Value': '7.2',
              'stat2Label': 'RPG',
              'stat3Value': '6.8',
              'stat3Label': 'APG',
            },
          ],
        ),
      ],
    );
